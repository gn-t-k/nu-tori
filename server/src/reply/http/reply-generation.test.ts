import { beforeEach, describe, expect, test, vi } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { addDays } from "../../domain/add-days";
import { generateRecordId } from "../../domain/record-id";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { postGoalSetup } from "../../http/goal-setup-routes/testing/post-goal-setup";
import { recordDailyWeights } from "../../http/goal-setup-routes/testing/record-daily-weights";
import { enableUsageEventSending } from "../../http/sync-routes/testing/enable-usage-event-sending";
import { pullSyncChanges, type PullResult } from "../../http/sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../../http/sync-routes/testing/push-sync-writes";
import { readRows } from "../../http/sync-routes/testing/read-rows";
import { signInTestAccount } from "../../http/testing";
import { createMealWrite } from "../../meal/http/testing/create-meal-write";
import { deleteMealWrite } from "../../meal/http/testing/delete-meal-write";
import { mockCaptureExceptionOk } from "../../observability/capture-exception.mock";
import { mockSetUserOk } from "../../observability/set-user.mock";
import {
  mockPostHogCaptureEndpointOk,
  readPostHogCapturedEvents,
} from "../../observability/testing";
import { createSentTextWrite } from "../../sent-text/http/testing/create-sent-text-write";
import { LlmCallBadRequestError } from "../../domain/llm-call-bad-request-error";
import { LlmCallError } from "../../domain/llm-call-error";
import { LlmCallInvalidResponseError } from "../../domain/llm-call-invalid-response-error";
import { LlmCallTimedOutError } from "../../domain/llm-call-timed-out-error";
import {
  mockCreateConversationProviderError,
  mockCreateConversationProviderOk,
} from "../durable-object/create-conversation-provider/create-conversation-provider.mock";
import { markTestUser } from "../../subscription-status/http/testing/mark-test-user";
import { placeFreeTrialLastDay } from "../../subscription-status/http/testing/place-free-trial-last-day";
import { insertCountedReplyRequests } from "./testing/insert-counted-reply-requests";
import { readGenerateReplyContexts } from "./testing/read-generate-reply-contexts";

describe("返事を作る", () => {
  let accountId: string;
  let sessionToken: string;
  let clock: ReturnType<typeof useFakeClock>;
  let pullRecordsOf: (kind: string) => Promise<Record<string, unknown>[]>;
  let readAttemptResults: () => Promise<Record<string, unknown>[]>;
  // 東京（ユーザーの最新のタイムゾーン）での今日
  let todayInTokyo: () => string;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく。
    // 時刻は UTC の 03:00（東京の 12:00、ニューヨークの前の日の 23:00）にする（数える日を見分けるため）
    const tomorrow = new Date(Date.now() + 86_400_000);
    clock = useFakeClock(
      Date.UTC(tomorrow.getUTCFullYear(), tomorrow.getUTCMonth(), tomorrow.getUTCDate() + 1, 3),
    );
    pullRecordsOf = async (kind) =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes
        .filter((change) => change.kind === kind)
        .map(({ record }) => record);
    readAttemptResults = () =>
      readRows(
        accountId,
        `SELECT result, error_type FROM reply_generation_attempts
         LEFT JOIN reply_generation_attempt_results
           ON reply_generation_attempt_results.reply_generation_attempt_id = reply_generation_attempts.id
         LEFT JOIN reply_generation_attempt_errors
           ON reply_generation_attempt_errors.reply_generation_attempt_id = reply_generation_attempts.id
         ORDER BY attempted_at`,
      );
    todayInTokyo = () =>
      new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(Date.now());
  });

  const sendText = async (sentText: Record<string, unknown> = {}) => {
    const write = createSentTextWrite({ sentText });
    await pushSyncWrites(sessionToken, { writes: [write] });
    return String(write.sentText["id"]);
  };

  // 次に試みる時刻を過ぎるまで時計を進めて（いちばん長い待ちは 8 分）、アラームを動かす
  const runRetryAlarm = async () => {
    clock.advance(10 * 60_000);
    await runEstimationAlarm(accountId);
  };

  describe("会話と読み分けた文章の返事を作れたとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: { body: "お昼はしっかり食べられていますね。", mealIds: [] },
      });
      sentTextId = await sendText({ body: "今日のお昼どうだった？" });
      await runEstimationAlarm(accountId);
    });

    test("返事が記録として届き、ID が返事の生成の ID と同じであること", async () => {
      const generations = await readRows(accountId, "SELECT id FROM reply_generations");
      expect(await pullRecordsOf("ai_utterance")).toEqual([
        {
          id: generations[0]?.["id"],
          body: "お昼はしっかり食べられていますね。",
          sentTextId,
          mealIds: [],
        },
      ]);
    });

    test("送った文章の状態が返事ありで届くこと", async () => {
      expect(await pullRecordsOf("sent_text_status")).toEqual([
        { sentTextId, classification: "conversation", replyStatus: "replied" },
      ]);
    });
  });

  describe("会話の文章を2つ続けて送ったとき", () => {
    let replySpy: ReturnType<typeof mockCreateConversationProviderOk>;
    beforeEach(async () => {
      replySpy = mockCreateConversationProviderOk({
        classification: "conversation",
        reply: (context) => ({ body: `「${context.newUtterance.body}」への返事`, mealIds: [] }),
      });
      await sendText({ body: "おはよう", sentAt: Date.now() - 120_000 });
      await sendText({ body: "今日は何を食べよう", sentAt: Date.now() - 60_000 });
      await runEstimationAlarm(accountId);
    });

    test("送った順に作り、先に作った返事をあとの文章の文脈の窓に入れること", () => {
      expect(
        readGenerateReplyContexts(replySpy).map(({ window, newUtterance }) => ({
          window: window.map((entry) => ("body" in entry ? entry.body : entry.type)),
          newUtterance: newUtterance.body,
        })),
      ).toEqual([
        { window: [], newUtterance: "おはよう" },
        { window: ["おはよう", "「おはよう」への返事"], newUtterance: "今日は何を食べよう" },
      ]);
    });
  });

  describe("目標を決める要求で目標を立てたあと、会話の文章を送ったとき", () => {
    let replySpy: ReturnType<typeof mockCreateConversationProviderOk>;
    let deadlineOn: string;
    beforeEach(async () => {
      // 体重が 70 kg のまま、使い始める前の摂取エネルギーが毎日 2,400 kcal。
      // 逆算した推定消費カロリーは 2,400 kcal で、標準の案は 65.5 kg、1日の目安 2,000 kcal
      const today = todayInTokyo();
      const windowDays = Array.from({ length: 28 }, (_, index) => addDays(today, index - 28));
      deadlineOn = addDays(today, 90);
      await recordDailyWeights(sessionToken, windowDays, 70);
      const response = await postGoalSetup(sessionToken, "decisions", {
        requestId: generateRecordId(),
        startedOn: today,
        choice: { type: "proposal", direction: "lose", deadlineOn, pace: "standard" },
        shown: {
          targetWeightKg: 65.5,
          dailyGuide: { energyKcal: 2000, proteinG: 105, fatG: 55, carbohydrateG: 270 },
        },
        rejectedCustomTargetWeightCount: 0,
        preUseEnergyIntakes: windowDays.map((calendarDay) => ({ calendarDay, kcal: 2400 })),
      });
      const decision = await response.json<{ status: string }>();
      if (decision.status !== "decided") {
        throw new Error(`目標を決められなかった: ${response.status} ${decision.status}`);
      }
      replySpy = mockCreateConversationProviderOk({
        classification: "conversation",
        reply: { body: "目標に向けて順調です。", mealIds: [] },
      });
      await sendText({ body: "今日はあと何を食べられる？" });
      await runEstimationAlarm(accountId);
    });

    test("文脈に、目標と今日の1日の目安と推定消費カロリーが入ること", () => {
      expect(
        readGenerateReplyContexts(replySpy).map(({ structuredValues }) => structuredValues.goal),
      ).toEqual([
        {
          direction: "lose",
          deadlineOn,
          targetWeightKg: 65.5,
          dailyGuide: { energyKcal: 2000, proteinG: 105, fatG: 55, carbohydrateG: 270 },
          expenditureKcal: 2400,
          latestWeeklyReview: undefined,
          // 今日立てた目標なので、まだ出ない
          pace: { status: "pending" },
        },
      ]);
    });
  });

  describe("返事が今日の食事を指し示したとき", () => {
    let sentTextId: string;
    let breakfastId: string;
    let lunchId: string;
    beforeEach(async () => {
      // 東京の 08:00 と 11:00 に食べた写真の食事（写真は送らないので、推定は写真を待ったまま）
      breakfastId = generateRecordId();
      lunchId = generateRecordId();
      await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({
            meal: {
              id: breakfastId,
              eatenAt: Date.now() - 4 * 3_600_000,
              sentAt: Date.now() - 4 * 3_600_000,
            },
          }),
          createMealWrite({
            meal: { id: lunchId, eatenAt: Date.now() - 3_600_000, sentAt: Date.now() - 3_600_000 },
          }),
        ],
      });
      // 文脈で ID を付けた今日の食事を、食べた順と逆に指す
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: (context) => ({
          body: "お昼の量を直してください。",
          mealIds: context.structuredValues.todayMeals.map(({ mealId }) => mealId).toReversed(),
        }),
      });
      sentTextId = await sendText({ body: "お昼の量が違うかも" });
      await runEstimationAlarm(accountId);
    });

    test("指し示す食事が返事の中の並びで届くこと", async () => {
      expect(await pullRecordsOf("ai_utterance")).toEqual([
        expect.objectContaining({ sentTextId, mealIds: [lunchId, breakfastId] }),
      ]);
    });

    describe("指し示した食事を消したとき", () => {
      beforeEach(async () => {
        await pushSyncWrites(sessionToken, { writes: [deleteMealWrite(lunchId)] });
      });

      test("指し示しが残ること", async () => {
        expect({
          utterances: await pullRecordsOf("ai_utterance"),
          rows: await readRows(
            accountId,
            "SELECT meal_id, position_in_utterance FROM ai_utterance_meals ORDER BY position_in_utterance",
          ),
        }).toEqual({
          utterances: [expect.objectContaining({ mealIds: [lunchId, breakfastId] })],
          rows: [
            { meal_id: lunchId, position_in_utterance: 0 },
            { meal_id: breakfastId, position_in_utterance: 1 },
          ],
        });
      });
    });
  });

  describe("その日の返事の生成が 9 回のとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      await insertCountedReplyRequests(accountId, todayInTokyo(), { generated: 9, halted: 0 });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("10 回目の返事を作ること", async () => {
      expect(await pullRecordsOf("sent_text_status")).toEqual([
        { sentTextId, classification: "conversation", replyStatus: "replied" },
      ]);
    });
  });

  describe("その日の返事の生成が 10 回のとき", () => {
    let sentTextId: string;
    let replySpy: ReturnType<typeof mockCreateConversationProviderOk>;
    beforeEach(async () => {
      replySpy = mockCreateConversationProviderOk({ classification: "conversation" });
      await insertCountedReplyRequests(accountId, todayInTokyo(), { generated: 10, halted: 0 });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("提供元を呼ばずに、送った文章の状態が回数切れで届くこと", async () => {
      expect({
        calls: readGenerateReplyContexts(replySpy).length,
        statuses: await pullRecordsOf("sent_text_status"),
        utterances: await pullRecordsOf("ai_utterance"),
      }).toEqual({
        calls: 0,
        statuses: [
          {
            sentTextId,
            classification: "conversation",
            replyStatus: "halted",
            replyHaltReason: "daily_limit",
          },
        ],
        utterances: [],
      });
    });

    describe("次のアラームが動いたとき", () => {
      beforeEach(async () => {
        await runRetryAlarm();
      });

      test("翌日に回さず、回数切れのままであること", async () => {
        expect({
          calls: readGenerateReplyContexts(replySpy).length,
          statuses: await pullRecordsOf("sent_text_status"),
        }).toEqual({
          calls: 0,
          statuses: [
            {
              sentTextId,
              classification: "conversation",
              replyStatus: "halted",
              replyHaltReason: "daily_limit",
            },
          ],
        });
      });
    });
  });

  describe("その日に 9 回生成し、1 回回数切れにしたとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      await insertCountedReplyRequests(accountId, todayInTokyo(), { generated: 9, halted: 1 });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("回数切れを数えずに返事を作ること", async () => {
      expect(await pullRecordsOf("sent_text_status")).toEqual([
        { sentTextId, classification: "conversation", replyStatus: "replied" },
      ]);
    });
  });

  describe("送った文章のタイムゾーンでの日に 10 回生成していて、最新のタイムゾーンでの日には生成していないとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      const todayInNewYork = new Intl.DateTimeFormat("en-CA", {
        timeZone: "America/New_York",
      }).format(Date.now());
      await insertCountedReplyRequests(accountId, todayInNewYork, { generated: 10, halted: 0 });
      // 端末のタイムゾーン（東京）と違うタイムゾーンで送る
      sentTextId = await sendText({ timeZone: "America/New_York" });
      await runEstimationAlarm(accountId);
    });

    test("依頼を作った時点の最新のタイムゾーンでの日に数えて、返事を作ること", async () => {
      expect(await pullRecordsOf("sent_text_status")).toEqual([
        { sentTextId, classification: "conversation", replyStatus: "replied" },
      ]);
    });
  });

  describe("提供元がエラーを返したとき", () => {
    let sentTextId: string;
    let providerResponseError: Error;
    let setUserSpy: ReturnType<typeof mockSetUserOk>;
    let captureExceptionSpy: ReturnType<typeof mockCaptureExceptionOk>;
    let logSpy: ReturnType<typeof vi.spyOn>;
    beforeEach(async () => {
      providerResponseError = new Error("Overloaded");
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new LlmCallError({
          errorType: "overloaded_error",
          cause: providerResponseError,
        }),
      });
      sentTextId = await sendText();
      setUserSpy = mockSetUserOk();
      captureExceptionSpy = mockCaptureExceptionOk();
      logSpy = vi.spyOn(console, "log");
      await runEstimationAlarm(accountId);
    });

    test("応答待ちのまま、やり直しを待つこと", async () => {
      expect(await pullRecordsOf("sent_text_status")).toEqual([
        { sentTextId, classification: "conversation", replyStatus: "awaiting" },
      ]);
    });

    test("試みの結果と、提供元のエラーの種類を書くこと", async () => {
      expect(await readAttemptResults()).toEqual([
        { result: "provider_error", error_type: "overloaded_error" },
      ]);
    });

    test("提供元の応答のエラーを、包まずにアカウント ID を付けて Sentry に送ること", () => {
      expect({
        user: setUserSpy.mock.calls.at(-1)?.[0],
        exceptions: captureExceptionSpy.mock.calls.map(([error]) => error),
      }).toEqual({ user: { id: accountId }, exceptions: [providerResponseError] });
    });

    test("アラームの呼び出しのログに、試みの結果と提供元のエラーの種類を出すこと", () => {
      expect(logSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          accountId,
          route: "alarm",
          replyAttempts: [{ result: "provider_error", errorType: "overloaded_error" }],
        }),
      );
    });

    describe("やり直しで返事を作れたとき", () => {
      beforeEach(async () => {
        mockCreateConversationProviderOk({ classification: "conversation" });
        await runRetryAlarm();
      });

      test("返事が届き、送った文章の状態が返事ありになること", async () => {
        expect({
          utterances: await pullRecordsOf("ai_utterance"),
          statuses: await pullRecordsOf("sent_text_status"),
        }).toEqual({
          utterances: [expect.objectContaining({ sentTextId })],
          statuses: [{ sentTextId, classification: "conversation", replyStatus: "replied" }],
        });
      });
    });

    describe("6回やり直しても通らなかったとき", () => {
      beforeEach(async () => {
        for (let retry = 0; retry < 6; retry += 1) {
          await runRetryAlarm();
        }
      });

      test("7つの試みのあと、作れなかった（やり直しを使い切った）で届くこと", async () => {
        expect({
          attempts: (await readAttemptResults()).length,
          statuses: await pullRecordsOf("sent_text_status"),
          utterances: await pullRecordsOf("ai_utterance"),
        }).toEqual({
          attempts: 7,
          statuses: [
            {
              sentTextId,
              classification: "conversation",
              replyStatus: "failed",
              replyFailureReason: "retries_exhausted",
            },
          ],
          utterances: [],
        });
      });
    });
  });

  describe("提供元の呼び出しが時間切れになったとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new LlmCallTimedOutError(),
      });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("試みの結果を時間切れにし、応答待ちのままやり直しを待つこと", async () => {
      expect({
        attempts: await readAttemptResults(),
        statuses: await pullRecordsOf("sent_text_status"),
      }).toEqual({
        attempts: [{ result: "timed_out", error_type: null }],
        statuses: [{ sentTextId, classification: "conversation", replyStatus: "awaiting" }],
      });
    });
  });

  describe("提供元の応答が出力の上限で切れたとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new LlmCallInvalidResponseError({
          usage: { inputTokens: 2400, outputTokens: 1024 },
        }),
      });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("試みの結果を読めない応答にし、応答待ちのままやり直しを待つこと", async () => {
      expect({
        attempts: await readAttemptResults(),
        statuses: await pullRecordsOf("sent_text_status"),
      }).toEqual({
        attempts: [{ result: "invalid_response", error_type: null }],
        statuses: [{ sentTextId, classification: "conversation", replyStatus: "awaiting" }],
      });
    });
  });

  describe("返事が文脈で ID を付けていない食事を指し示したとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: { body: "その食事を直してください。", mealIds: [generateRecordId()] },
      });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("返事を書かず、読めない応答としてやり直しを待つこと", async () => {
      expect({
        attempts: await readAttemptResults(),
        statuses: await pullRecordsOf("sent_text_status"),
        utterances: await pullRecordsOf("ai_utterance"),
      }).toEqual({
        attempts: [{ result: "invalid_response", error_type: null }],
        statuses: [{ sentTextId, classification: "conversation", replyStatus: "awaiting" }],
        utterances: [],
      });
    });
  });

  describe("返事が、在るが文脈で ID を付けていない3日前の食事を指し示したとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      const mealId = generateRecordId();
      const threeDaysAgo = Date.now() - 3 * 86_400_000;
      await pushSyncWrites(sessionToken, {
        writes: [
          createMealWrite({ meal: { id: mealId, eatenAt: threeDaysAgo, sentAt: threeDaysAgo } }),
        ],
      });
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: { body: "その食事を直してください。", mealIds: [mealId] },
      });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("返事を書かず、読めない応答としてやり直しを待つこと", async () => {
      expect({
        attempts: await readAttemptResults(),
        statuses: await pullRecordsOf("sent_text_status"),
      }).toEqual({
        attempts: [{ result: "invalid_response", error_type: null }],
        statuses: [{ sentTextId, classification: "conversation", replyStatus: "awaiting" }],
      });
    });
  });

  describe("提供元が 400 を返したとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new LlmCallBadRequestError({
          errorType: "invalid_request_error",
          cause: new Error("Bad Request"),
        }),
      });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("やり直さずに、作れなかった（400）で届くこと", async () => {
      expect({
        attempts: await readAttemptResults(),
        statuses: await pullRecordsOf("sent_text_status"),
      }).toEqual({
        attempts: [{ result: "bad_request", error_type: "invalid_request_error" }],
        statuses: [
          {
            sentTextId,
            classification: "conversation",
            replyStatus: "failed",
            replyFailureReason: "bad_request",
          },
        ],
      });
    });
  });

  describe("利用状況を送る人の文章の返事を作ったとき", () => {
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: { body: "よく眠れましたか。", mealIds: [] },
        replyUsage: { inputTokens: 2400, outputTokens: 180 },
      });
      await sendText({ body: "おはよう" });
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("本文を含めずに、返事の呼び出しと生成の出来事を送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(({ event }) => event.startsWith("reply_")),
      ).toEqual([
        {
          event: "reply_attempt_ended",
          distinct_id: accountId,
          properties: {
            $geoip_disable: true,
            result: "succeeded",
            input_tokens: 2400,
            output_tokens: 180,
          },
        },
        {
          event: "reply_generation_ended",
          distinct_id: accountId,
          properties: {
            $geoip_disable: true,
            final_status: "replied",
            retry_count: 0,
            referenced_meal_count: 0,
            seconds_from_requested_to_ended: 0,
            provider_error_types: [],
          },
        },
      ]);
    });
  });

  describe("利用状況を送る人の依頼を回数切れにしたとき", () => {
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await enableUsageEventSending(accountId);
      mockCreateConversationProviderOk({ classification: "conversation" });
      await insertCountedReplyRequests(accountId, todayInTokyo(), { generated: 10, halted: 0 });
      await sendText({ body: "今日はもう一回聞きたい" });
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("本文を含めずに、回数切れの出来事を送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(({ event }) => event.startsWith("reply_")),
      ).toEqual([
        {
          event: "reply_request_halted",
          distinct_id: accountId,
          properties: { reason: "daily_limit", $geoip_disable: true },
        },
      ]);
    });
  });

  describe("無料体験が終わったアカウントが、会話の文章を送ったとき", () => {
    let sentTextId: string;
    let replySpy: ReturnType<typeof mockCreateConversationProviderOk>;
    let captureSpy: ReturnType<typeof mockPostHogCaptureEndpointOk>;
    beforeEach(async () => {
      await placeFreeTrialLastDay(accountId, addDays(todayInTokyo(), -10));
      await enableUsageEventSending(accountId);
      replySpy = mockCreateConversationProviderOk({ classification: "conversation" });
      sentTextId = await sendText();
      captureSpy = mockPostHogCaptureEndpointOk();
      await runEstimationAlarm(accountId);
    });

    test("提供元を呼ばずに、送った文章の状態がサブスクリプション切れの止めで届くこと", async () => {
      expect({
        calls: readGenerateReplyContexts(replySpy).length,
        statuses: await pullRecordsOf("sent_text_status"),
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
      });
    });

    test("止めた出来事を、理由をサブスクリプション切れにして送ること", () => {
      expect(
        readPostHogCapturedEvents(captureSpy).filter(({ event }) => event.startsWith("reply_")),
      ).toEqual([
        {
          event: "reply_request_halted",
          distinct_id: accountId,
          properties: { reason: "subscription_expired", $geoip_disable: true },
        },
      ]);
    });

    describe("そのあとテストユーザーの旗を立て、次のアラームが動いたとき", () => {
      beforeEach(async () => {
        await markTestUser(accountId);
        await runRetryAlarm();
      });

      test("返事を作り直さず、止めたままであること", async () => {
        expect({
          calls: readGenerateReplyContexts(replySpy).length,
          statuses: await pullRecordsOf("sent_text_status"),
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
        });
      });
    });
  });

  describe("無料体験が終わったテストユーザーが、会話の文章を送ったとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      await placeFreeTrialLastDay(accountId, addDays(todayInTokyo(), -10));
      await markTestUser(accountId);
      mockCreateConversationProviderOk({ classification: "conversation" });
      sentTextId = await sendText();
      await runEstimationAlarm(accountId);
    });

    test("返事を作ること", async () => {
      expect(await pullRecordsOf("sent_text_status")).toEqual([
        { sentTextId, classification: "conversation", replyStatus: "replied" },
      ]);
    });
  });
});
