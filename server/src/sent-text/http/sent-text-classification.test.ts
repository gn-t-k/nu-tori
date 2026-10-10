import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId } from "../../domain/record-id";
import { mockCreateEstimationProviderOk } from "../../estimation/durable-object/create-estimation-provider/create-estimation-provider.mock";
import { insertCountedEstimations } from "../../estimation/http/testing/insert-counted-estimations";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { ConversationProviderError } from "../../reply/domain/conversation-provider-error";
import {
  mockCreateConversationProviderError,
  mockCreateConversationProviderOk,
} from "../../reply/durable-object/create-conversation-provider/create-conversation-provider.mock";
import { createSentTextWrite } from "./testing/create-sent-text-write";

describe("読み分け", () => {
  let accountId: string;
  let sessionToken: string;
  let pullChanges: () => Promise<PullResult["changes"]>;
  let pullRecordsOf: (kind: string) => Promise<Record<string, unknown>[]>;
  let countEstimations: () => Promise<number>;
  let readReplyRequests: () => Promise<Record<string, unknown>[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく。
    // 時刻は UTC の 20:00 にし、東京では次の日、ニューヨークでは同じ日にする（数える日を見分けるため）
    const tomorrow = new Date(Date.now() + 86_400_000);
    useFakeClock(
      Date.UTC(tomorrow.getUTCFullYear(), tomorrow.getUTCMonth(), tomorrow.getUTCDate() + 1, 20),
    );
    pullChanges = async () =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes;
    pullRecordsOf = async (kind) =>
      (await pullChanges()).filter((change) => change.kind === kind).map(({ record }) => record);
    countEstimations = async () => (await readRows(accountId, "SELECT id FROM estimations")).length;
    readReplyRequests = () =>
      readRows(
        accountId,
        `SELECT reply_requests.sent_text_id, reply_requests.counted_on,
                classification_reply_requests.reply_request_id IS NOT NULL AS by_classification
         FROM reply_requests
         LEFT JOIN classification_reply_requests
           ON classification_reply_requests.reply_request_id = reply_requests.id`,
      );
  });

  const sendText = async (sentText: Record<string, unknown> = {}) => {
    const write = createSentTextWrite({ sentText });
    await pushSyncWrites(sessionToken, { writes: [write] });
    return String(write.sentText["id"]);
  };

  describe("食事と読み分けたとき", () => {
    let sentTextId: string;
    let sentAt: number;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "meal" });
      mockCreateEstimationProviderOk();
      sentAt = Date.now() - 60_000;
      sentTextId = await sendText({ sentAt, timeZone: "Asia/Tokyo" });
      await runEstimationAlarm(accountId);
    });

    test("送った時刻とタイムゾーンが文章と同じ、入口が文章の食事が1つ届くこと", async () => {
      expect(await pullRecordsOf("meal")).toEqual([
        {
          id: expect.any(String),
          eatenAt: sentAt,
          eatenAtUtcOffsetSeconds: 32_400,
          sentAt,
          sentTimeZone: "Asia/Tokyo",
          entryMethod: "written",
          photos: [],
          sentTextId,
        },
      ]);
    });

    test("送った文章の状態が食事で届くこと", async () => {
      expect(await pullRecordsOf("sent_text_status")).toEqual([
        { sentTextId, classification: "meal" },
      ]);
    });

    test("推定の予定に入り、同じアラームで推定されること", async () => {
      expect({
        estimations: await countEstimations(),
        statuses: (await pullRecordsOf("meal_estimation_status")).map(({ status }) => status),
      }).toEqual({ estimations: 1, statuses: ["estimated"] });
    });

    test("返事の依頼を作らないこと", async () => {
      expect(await readReplyRequests()).toEqual([]);
    });
  });

  describe("その日の推定が 30 回に達しているときに、食事と読み分けたとき", () => {
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "meal" });
      mockCreateEstimationProviderOk();
      const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(Date.now());
      await insertCountedEstimations(accountId, today, 30);
      await sendText();
      await runEstimationAlarm(accountId);
    });

    test("文章の食事を翌日に推定すること", async () => {
      expect((await pullRecordsOf("meal_estimation_status")).map(({ status }) => status)).toEqual([
        "deferred_to_next_day",
      ]);
    });
  });

  describe.for([
    {
      name: "会話と読み分けたとき",
      arrange: () => mockCreateConversationProviderOk({ classification: "conversation" }),
    },
    {
      name: "決めかねたとき",
      arrange: () => mockCreateConversationProviderOk({ classification: "unsure" }),
    },
    {
      name: "読み分けの呼び出しが失敗したとき",
      arrange: () =>
        mockCreateConversationProviderError(
          new ConversationProviderError({ errorType: "overloaded_error" }),
        ),
    },
  ])("$name", ({ arrange }) => {
    let sentTextId: string;
    beforeEach(async () => {
      arrange();
      mockCreateEstimationProviderOk();
      // 端末のタイムゾーン（東京）と違うタイムゾーンで送る
      sentTextId = await sendText({ timeZone: "America/New_York" });
      await runEstimationAlarm(accountId);
    });

    test("送った文章の状態が会話で届くこと", async () => {
      expect(await pullRecordsOf("sent_text_status")).toEqual([
        { sentTextId, classification: "conversation" },
      ]);
    });

    test("きっかけが読み分けの返事の依頼を、ユーザーの最新のタイムゾーンでの今日の分として作ること", async () => {
      expect(await readReplyRequests()).toEqual([
        {
          sent_text_id: sentTextId,
          counted_on: new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(
            Date.now(),
          ),
          by_classification: 1,
        },
      ]);
    });

    test("食事を作らず、推定もしないこと", async () => {
      expect({
        meals: await pullRecordsOf("meal"),
        estimations: await countEstimations(),
      }).toEqual({ meals: [], estimations: 0 });
    });
  });

  describe("後に送った文章が先に届いたとき", () => {
    let earlierId: string;
    let laterId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      laterId = await sendText({ sentAt: Date.now() - 60_000 });
      earlierId = await sendText({ sentAt: Date.now() - 120_000 });
      await runEstimationAlarm(accountId);
    });

    test("送った順に読み分けること", async () => {
      expect(
        (await pullRecordsOf("sent_text_status"))
          .filter(({ classification }) => classification !== "pending")
          .map(({ sentTextId }) => sentTextId),
      ).toEqual([earlierId, laterId]);
    });
  });

  describe("利用状況を送る人の文章を読み分けたとき", () => {
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockCreateConversationProviderOk({
        classification: "unsure",
        classificationUsage: { inputTokens: 150, outputTokens: 3 },
      });
      await sendText({ body: "今日は何を食べようかな" });
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("本文を含めずに、読み分けの出来事を送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(
          ({ event }) => event === "sent_text_classified",
        ),
      ).toEqual([
        {
          event: "sent_text_classified",
          distinct_id: accountId,
          properties: {
            $geoip_disable: true,
            result: "conversation",
            provider_result: "unsure",
            input_tokens: 150,
            output_tokens: 3,
            seconds_from_received_to_classified: 0,
          },
        },
      ]);
    });
  });
});
