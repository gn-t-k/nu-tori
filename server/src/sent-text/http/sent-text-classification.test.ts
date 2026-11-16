import { beforeEach, describe, expect, test, vi } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
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
import { mockCaptureExceptionOk } from "../../observability/capture-exception.mock";
import { mockSetUserOk } from "../../observability/set-user.mock";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { LlmCallError } from "../../domain/llm-call-error";
import {
  mockCreateConversationProviderError,
  mockCreateConversationProviderOk,
} from "../../reply/durable-object/create-conversation-provider/create-conversation-provider.mock";
import { placeFreeTrialLastDay } from "../../subscription-status/http/testing/place-free-trial-last-day";
import { createSentTextWrite } from "./testing/create-sent-text-write";
import { insertCountedClassificationCalls } from "./testing/insert-counted-classification-calls";

const todayInTokyo = () =>
  new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(Date.now());

// 偽の提供元の読み分けが呼ばれた回数。作る口は毎回同じ偽物を返すので、1つ目の結果で数える
const countClassifyCalls = (spy: ReturnType<typeof mockCreateConversationProviderOk>) => {
  const provider = spy.mock.results[0]?.value;
  return provider === undefined ? 0 : vi.mocked(provider.classifySentText).mock.calls.length;
};

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
        { sentTextId, classification: "meal", replyStatus: "none" },
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

  describe("その日の推定が 15 回に達しているときに、食事と読み分けたとき", () => {
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "meal" });
      mockCreateEstimationProviderOk();
      const today = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(Date.now());
      await insertCountedEstimations(accountId, today, 15);
      await sendText();
      await runEstimationAlarm(accountId);
    });

    test("文章の食事を翌日に推定すること", async () => {
      expect((await pullRecordsOf("meal_estimation_status")).map(({ status }) => status)).toEqual([
        "deferred_to_next_day",
      ]);
    });
  });

  describe("会話にするとき", () => {
    describe("会話と読み分けたなら", () => {
      let sentTextId: string;
      beforeEach(async () => {
        mockCreateConversationProviderOk({ classification: "conversation" });
        mockCreateEstimationProviderOk();
        // 端末のタイムゾーン（東京）と違うタイムゾーンで送る
        sentTextId = await sendText({ timeZone: "America/New_York" });
        await runEstimationAlarm(accountId);
      });

      // 返事は同じアラームで作るので、応答の状態は返事あり
      test("送った文章の状態が会話で届くこと", async () => {
        expect(await pullRecordsOf("sent_text_status")).toEqual([
          { sentTextId, classification: "conversation", replyStatus: "replied" },
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

    describe("決めかねたなら", () => {
      let sentTextId: string;
      beforeEach(async () => {
        mockCreateConversationProviderOk({ classification: "unsure" });
        mockCreateEstimationProviderOk();
        // 端末のタイムゾーン（東京）と違うタイムゾーンで送る
        sentTextId = await sendText({ timeZone: "America/New_York" });
        await runEstimationAlarm(accountId);
      });

      // 返事は同じアラームで作るので、応答の状態は返事あり
      test("送った文章の状態が会話で届くこと", async () => {
        expect(await pullRecordsOf("sent_text_status")).toEqual([
          { sentTextId, classification: "conversation", replyStatus: "replied" },
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

    describe("読み分けの呼び出しが失敗したなら", () => {
      let sentTextId: string;
      beforeEach(async () => {
        mockCreateConversationProviderError({
          failingCall: "classify_sent_text",
          error: new LlmCallError({ errorType: "overloaded_error" }),
        });
        mockCreateEstimationProviderOk();
        // 端末のタイムゾーン（東京）と違うタイムゾーンで送る
        sentTextId = await sendText({ timeZone: "America/New_York" });
        await runEstimationAlarm(accountId);
      });

      // 返事は同じアラームで作るので、応答の状態は返事あり
      test("送った文章の状態が会話で届くこと", async () => {
        expect(await pullRecordsOf("sent_text_status")).toEqual([
          { sentTextId, classification: "conversation", replyStatus: "replied" },
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
  });

  // 本番のクレジットが尽きると、すべての文章が会話になり、食事が記録されない。Sentry の急増で気づく
  describe("読み分けの呼び出しが失敗したとき", () => {
    let providerResponseError: Error;
    let setUserSpy: ReturnType<typeof mockSetUserOk>;
    let captureExceptionSpy: ReturnType<typeof mockCaptureExceptionOk>;
    let logSpy: ReturnType<typeof vi.spyOn>;
    beforeEach(async () => {
      providerResponseError = new Error("Your credit balance is too low");
      mockCreateConversationProviderError({
        failingCall: "classify_sent_text",
        error: new LlmCallError({
          errorType: "invalid_request_error",
          cause: providerResponseError,
        }),
      });
      await sendText();
      setUserSpy = mockSetUserOk();
      captureExceptionSpy = mockCaptureExceptionOk();
      logSpy = vi.spyOn(console, "log");
      await runEstimationAlarm(accountId);
    });

    test("提供元の応答のエラーを、包まずにアカウント ID を付けて Sentry に送ること", () => {
      expect({
        user: setUserSpy.mock.calls.at(-1)?.[0],
        exceptions: captureExceptionSpy.mock.calls.map(([error]) => error),
      }).toEqual({ user: { id: accountId }, exceptions: [providerResponseError] });
    });

    test("アラームの呼び出しのログに、読み分けの結果と提供元のエラーの種類を出すこと", () => {
      expect(logSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          accountId,
          route: "alarm",
          classifications: [
            {
              result: "conversation",
              providerResult: "failed",
              providerErrorType: "invalid_request_error",
            },
          ],
        }),
      );
    });
  });

  describe("応答のエラーの無い失敗のとき", () => {
    let providerError: LlmCallError;
    let captureExceptionSpy: ReturnType<typeof mockCaptureExceptionOk>;
    beforeEach(async () => {
      providerError = new LlmCallError({ errorType: "invalid_response" });
      mockCreateConversationProviderError({
        failingCall: "classify_sent_text",
        error: providerError,
      });
      await sendText();
      captureExceptionSpy = mockCaptureExceptionOk();
      await runEstimationAlarm(accountId);
    });

    test("失敗そのものを Sentry に送ること", () => {
      expect(captureExceptionSpy.mock.calls.map(([error]) => error)).toEqual([providerError]);
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
        classificationUsage: { type: "uncached", inputTokens: 150, outputTokens: 3 },
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

  const readCountedCalls = (sentTextId: string) =>
    readRows(
      accountId,
      `SELECT counted_on FROM sent_text_classification_calls WHERE sent_text_id = '${sentTextId}'`,
    );

  describe("提供元を呼んで読み分けたとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      // 端末のタイムゾーン（東京）と違うタイムゾーンで送る
      sentTextId = await sendText({ timeZone: "America/New_York" });
      await runEstimationAlarm(accountId);
    });

    test("読み分けの回数を、ユーザーの最新のタイムゾーンでの今日の分として数えること", async () => {
      expect(await readCountedCalls(sentTextId)).toEqual([{ counted_on: todayInTokyo() }]);
    });
  });

  describe("読み分けの呼び出しが失敗したとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "classify_sent_text",
        error: new LlmCallError({ errorType: "overloaded_error" }),
      });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("読み分けの回数に数えること", async () => {
      expect(await readCountedCalls(sentTextId)).toEqual([{ counted_on: todayInTokyo() }]);
    });
  });

  describe("その日の読み分けが 49 回のときに、文章を2つ送ったとき", () => {
    let firstId: string;
    let secondId: string;
    let providerSpy: ReturnType<typeof mockCreateConversationProviderOk>;
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    let logSpy: ReturnType<typeof vi.spyOn>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      providerSpy = mockCreateConversationProviderOk({ classification: "meal" });
      mockCreateEstimationProviderOk();
      await insertCountedClassificationCalls(accountId, todayInTokyo(), 49);
      firstId = await sendText({ sentAt: Date.now() - 120_000 });
      secondId = await sendText({ sentAt: Date.now() - 60_000 });
      captureSpy = mockPostHogCaptureEndpointOk();
      logSpy = vi.spyOn(console, "log");
      await runEstimationAlarm(accountId);
    });

    test("50 回目の文章だけ提供元に読ませ、次の文章は呼ばずに回数切れの会話にすること", async () => {
      expect({
        calls: countClassifyCalls(providerSpy),
        statuses: (await pullRecordsOf("sent_text_status")).filter(
          ({ sentTextId }) => sentTextId === firstId || sentTextId === secondId,
        ),
      }).toEqual({
        calls: 1,
        statuses: [
          { sentTextId: firstId, classification: "meal", replyStatus: "none" },
          {
            sentTextId: secondId,
            classification: "conversation",
            replyStatus: "halted",
            replyHaltReason: "daily_limit",
          },
        ],
      });
    });

    test("呼ばなかった文章は、読み分けの回数に数えないこと", async () => {
      expect(await readCountedCalls(secondId)).toEqual([]);
    });

    test("呼ばなかった文章の出来事を、理由を1日の上限にして送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(
          ({ event }) => event === "sent_text_classification_skipped",
        ),
      ).toEqual([
        {
          event: "sent_text_classification_skipped",
          distinct_id: accountId,
          properties: { reason: "daily_limit", $geoip_disable: true },
        },
      ]);
    });

    test("アラームの呼び出しのログに、呼ばなかった理由を出すこと", () => {
      expect(logSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          accountId,
          route: "alarm",
          classifications: [
            { result: "meal", providerResult: "meal" },
            { result: "conversation", providerResult: "not_called", skipReason: "daily_limit" },
          ],
        }),
      );
    });
  });

  describe("前の日の読み分けが 50 回に達しているとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "meal" });
      mockCreateEstimationProviderOk();
      await insertCountedClassificationCalls(accountId, addDays(todayInTokyo(), -1), 50);
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("今日の文章を読み分けること", async () => {
      expect(
        (await pullRecordsOf("sent_text_status")).filter(
          (status) => status["sentTextId"] === sentTextId,
        ),
      ).toEqual([{ sentTextId, classification: "meal", replyStatus: "none" }]);
    });
  });

  describe("無料体験が終わったアカウントが、文章を送ったとき", () => {
    let sentTextId: string;
    let providerSpy: ReturnType<typeof mockCreateConversationProviderOk>;
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await placeFreeTrialLastDay(accountId, addDays(todayInTokyo(), -10));
      await enableUsageEventSending(accountId);
      providerSpy = mockCreateConversationProviderOk({ classification: "meal" });
      mockCreateEstimationProviderOk();
      sentTextId = await sendText();
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("提供元を呼ばずに、サブスクリプション切れの止めの会話にすること", async () => {
      expect({
        calls: countClassifyCalls(providerSpy),
        statuses: await pullRecordsOf("sent_text_status"),
        meals: await pullRecordsOf("meal"),
      }).toEqual({
        calls: 0,
        statuses: [
          {
            sentTextId,
            classification: "conversation",
            replyStatus: "halted",
            replyHaltReason: "subscription_expired",
          },
        ],
        meals: [],
      });
    });

    test("呼ばなかった文章の出来事を、理由をサブスクリプション切れにして送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(
          ({ event }) => event === "sent_text_classification_skipped",
        ),
      ).toEqual([
        {
          event: "sent_text_classification_skipped",
          distinct_id: accountId,
          properties: { reason: "subscription_expired", $geoip_disable: true },
        },
      ]);
    });
  });
});
