import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId } from "../../domain/record-id";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites, type PushResults } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import { ConversationProviderBadRequestError } from "../../reply/domain/conversation-provider-bad-request-error";
import {
  mockCreateConversationProviderError,
  mockCreateConversationProviderOk,
} from "../../reply/durable-object/create-conversation-provider/create-conversation-provider.mock";
import { insertCountedReplyRequests } from "../../reply/http/testing/insert-counted-reply-requests";
import { createSentTextWrite } from "./testing/create-sent-text-write";
import { resendSentTextWrite } from "./testing/resend-sent-text-write";

const statusesIn = (changes: PullResult["changes"]) =>
  changes.filter(({ kind }) => kind === "sent_text_status").map(({ record }) => record);

describe("送り直す", () => {
  let accountId: string;
  let sessionToken: string;
  let clock: ReturnType<typeof useFakeClock>;
  let pullChangesAfter: (afterSequence: number) => Promise<PullResult>;
  // 東京（ユーザーの最新のタイムゾーン）での今日
  let todayInTokyo: () => string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく。時刻は UTC の 03:00（東京の 12:00）にする
    const tomorrow = new Date(Date.now() + 86_400_000);
    clock = useFakeClock(
      Date.UTC(tomorrow.getUTCFullYear(), tomorrow.getUTCMonth(), tomorrow.getUTCDate() + 1, 3),
    );
    pullChangesAfter = async (afterSequence) =>
      (await pullSyncChanges(sessionToken, { afterSequence })).json<PullResult>();
    todayInTokyo = () =>
      new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(Date.now());
  });

  const sendText = async () => {
    const write = createSentTextWrite();
    await pushSyncWrites(sessionToken, { writes: [write] });
    return String(write.sentText["id"]);
  };

  const resend = async (sentTextId: string) =>
    (
      await (
        await pushSyncWrites(sessionToken, { writes: [resendSentTextWrite(sentTextId)] })
      ).json<PushResults>()
    ).results[0];

  const readResendRequests = () =>
    readRows(
      accountId,
      `SELECT reply_requests.sent_text_id, reply_requests.counted_on
       FROM resend_reply_requests
       INNER JOIN reply_requests ON reply_requests.id = resend_reply_requests.reply_request_id`,
    );

  describe("提供元の 400 で作れなかった文章を送り直したとき", () => {
    let sentTextId: string;
    let beforeResend: number;
    let result: PushResults["results"][number] | undefined;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new ConversationProviderBadRequestError({
          errorType: "invalid_request_error",
          cause: new Error("Bad Request"),
        }),
      });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
      beforeResend = (await pullChangesAfter(0)).nextAfterSequence;
      result = await resend(sentTextId);
    });

    test("当てたと返し、応答待ちになった文章の状態が一緒に届くこと", async () => {
      expect({
        result: result?.result,
        statuses: statusesIn((await pullChangesAfter(beforeResend)).changes),
      }).toEqual({
        result: "applied",
        statuses: [{ sentTextId, classification: "conversation", replyStatus: "awaiting" }],
      });
    });

    test("きっかけが送り直しの返事の依頼を、今日の分として作ること", async () => {
      expect(await readResendRequests()).toEqual([
        { sent_text_id: sentTextId, counted_on: todayInTokyo() },
      ]);
    });

    describe("アラームが動いたとき", () => {
      beforeEach(async () => {
        mockCreateConversationProviderOk();
        await runEstimationAlarm(accountId);
      });

      test("返事を作り、生成をまた回数に数えること", async () => {
        expect({
          statuses: statusesIn((await pullChangesAfter(beforeResend)).changes),
          generations: await readRows(accountId, "SELECT id FROM reply_generations"),
        }).toEqual({
          statuses: [{ sentTextId, classification: "conversation", replyStatus: "replied" }],
          generations: [expect.anything(), expect.anything()],
        });
      });
    });
  });

  describe("回数切れの文章を", () => {
    let sentTextId: string;
    let beforeResend: number;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      await insertCountedReplyRequests(accountId, todayInTokyo(), { generated: 20, halted: 0 });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    describe("同じ日に送り直したとき", () => {
      beforeEach(async () => {
        beforeResend = (await pullChangesAfter(0)).nextAfterSequence;
        await resend(sentTextId);
        await runEstimationAlarm(accountId);
      });

      test("回数をまた数えて、また回数切れにすること", async () => {
        expect(statusesIn((await pullChangesAfter(beforeResend)).changes)).toEqual([
          { sentTextId, classification: "conversation", replyStatus: "halted" },
        ]);
      });
    });

    describe("翌日に送り直したとき", () => {
      beforeEach(async () => {
        clock.advance(86_400_000);
        beforeResend = (await pullChangesAfter(0)).nextAfterSequence;
        await resend(sentTextId);
        await runEstimationAlarm(accountId);
      });

      test("翌日の分に数えて、返事を作ること", async () => {
        expect({
          requests: await readResendRequests(),
          statuses: statusesIn((await pullChangesAfter(beforeResend)).changes),
        }).toEqual({
          requests: [{ sent_text_id: sentTextId, counted_on: todayInTokyo() }],
          statuses: [{ sentTextId, classification: "conversation", replyStatus: "replied" }],
        });
      });
    });
  });

  describe("返事のある文章を送り直したとき", () => {
    let afterReplied: number;
    let result: PushResults["results"][number] | undefined;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      const sentTextId = await sendText();
      await runEstimationAlarm(accountId);
      afterReplied = (await pullChangesAfter(0)).nextAfterSequence;
      result = await resend(sentTextId);
    });

    test("当てたと返し、変更も返事の依頼も足さないこと", async () => {
      expect({
        result: result?.result,
        changes: (await pullChangesAfter(afterReplied)).changes,
        requests: await readResendRequests(),
      }).toEqual({ result: "applied", changes: [], requests: [] });
    });
  });

  describe("作れなかった文章を、2台の端末から送り直したとき", () => {
    let afterFirst: number;
    let second: PushResults["results"][number] | undefined;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new ConversationProviderBadRequestError({
          errorType: "invalid_request_error",
          cause: new Error("Bad Request"),
        }),
      });
      const sentTextId = await sendText();
      await runEstimationAlarm(accountId);
      await resend(sentTextId);
      afterFirst = (await pullChangesAfter(0)).nextAfterSequence;
      second = await resend(sentTextId);
    });

    test("応答待ちの文章への2つ目を、変更も返事の依頼も足さずに当てたと返すこと", async () => {
      expect({
        result: second?.result,
        changes: (await pullChangesAfter(afterFirst)).changes,
        requests: await readResendRequests(),
      }).toEqual({ result: "applied", changes: [], requests: [expect.anything()] });
    });
  });

  describe("返事を頼んでいない文章を送り直したとき", () => {
    test.each([
      { situation: "読み分ける前", classify: false },
      { situation: "食事と読み分けた", classify: true },
    ])("$situation 文章は、作れなかったでないとして受け付けないこと", async ({ classify }) => {
      mockCreateConversationProviderOk({ classification: "meal" });
      const sentTextId = await sendText();
      if (classify) {
        await runEstimationAlarm(accountId);
      }
      const result = await resend(sentTextId);
      expect({
        result: result?.result,
        rejectionReason: result?.rejectionReason,
        currentKind: result?.current?.change?.kind,
        receipts: await readRows(
          accountId,
          "SELECT kind, result FROM sync_write_receipts WHERE record_type = 'sent_text' AND kind != 'create'",
        ),
      }).toEqual({
        result: "rejected",
        rejectionReason: "reply_not_failed",
        currentKind: "sent_text",
        // 控えの kind で、送り直す書き込みと見分けられる
        receipts: [{ kind: "resend", result: "rejected" }],
      });
    });
  });

  describe("知らない文章を送り直したとき", () => {
    test("見つからないとして受け付けず、文章が無いことを添えること", async () => {
      const result = await resend(generateRecordId());
      expect({
        result: result?.result,
        rejectionReason: result?.rejectionReason,
        current: result?.current,
      }).toEqual({
        result: "rejected",
        rejectionReason: "record_not_found",
        current: { status: "absent" },
      });
    });
  });
});
