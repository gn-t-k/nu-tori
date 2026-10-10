import { beforeEach, describe, expect, test } from "vitest";
import { mockExchangeAppleAuthorizationCodeOk } from "../../auth/exchange-apple-authorization-code/exchange-apple-authorization-code.mock";
import { mockAppleKeysEndpointOk } from "../../auth/testing";
import { generateRecordId } from "../../domain/record-id";
import { runEstimationAlarm } from "../../estimation/http/testing/run-estimation-alarm";
import { useFakeClock } from "../../estimation/http/testing/use-fake-clock";
import { ConversationProviderBadRequestError } from "../../reply/domain/conversation-provider-bad-request-error";
import { ConversationProviderError } from "../../reply/domain/conversation-provider-error";
import { ConversationProviderTimedOutError } from "../../reply/domain/conversation-provider-timed-out-error";
import {
  mockCreateConversationProviderError,
  mockCreateConversationProviderOk,
} from "../../reply/durable-object/create-conversation-provider/create-conversation-provider.mock";
import { insertCountedReplyRequests } from "../../reply/http/testing/insert-counted-reply-requests";
import { createSentTextWrite } from "../../sent-text/http/testing/create-sent-text-write";
import { pullSyncChanges, type PullResult } from "../sync-routes/testing/pull-sync-changes";
import { pushSyncWrites } from "../sync-routes/testing/push-sync-writes";
import { readRows } from "../sync-routes/testing/read-rows";
import { signInTestAccount } from "../testing";
import { readReplyStreamEvents, watchReplyStream } from "./testing";

describe("見守る要求", () => {
  let accountId: string;
  let sessionToken: string;
  let clock: ReturnType<typeof useFakeClock>;
  let readGenerationIds: () => Promise<unknown[]>;
  let pullRecordsOf: (kind: string) => Promise<Record<string, unknown>[]>;
  beforeEach(async () => {
    mockAppleKeysEndpointOk();
    mockExchangeAppleAuthorizationCodeOk();
    ({ accountId, sessionToken } = await signInTestAccount(generateRecordId()));
    // 張ったアラームがひとりでに動かないよう、時計を先に進めておく
    clock = useFakeClock(Date.now() + 2 * 86_400_000);
    readGenerationIds = async () =>
      (await readRows(accountId, "SELECT id FROM reply_generations")).map(({ id }) => id);
    pullRecordsOf = async (kind) =>
      (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes
        .filter((change) => change.kind === kind)
        .map(({ record }) => record);
  });

  const sendText = async (sentText: Record<string, unknown> = {}) => {
    const write = createSentTextWrite({ sentText });
    await pushSyncWrites(sessionToken, { writes: [write] });
    return String(write.sentText["id"]);
  };

  describe("読み分ける前につなぎ、会話と読み分けて返事を作れたとき", () => {
    let response: Response;
    beforeEach(async () => {
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: {
          body: "お昼はしっかり食べられていますね。",
          mealIds: [],
          textDeltas: ["お昼はしっかり", "食べられていますね。"],
        },
      });
      const sentTextId = await sendText({ body: "今日のお昼どうだった？" });
      response = await watchReplyStream(sessionToken, sentTextId);
      await runEstimationAlarm(accountId);
    });

    test("text/event-stream で応えること", () => {
      expect({
        status: response.status,
        contentType: response.headers.get("content-type"),
      }).toEqual({ status: 200, contentType: "text/event-stream" });
    });

    test("はじめに返事の ID、続けてできた分が流れ、返事ありで閉じること", async () => {
      const [replyId] = await readGenerationIds();
      expect(await readReplyStreamEvents(response)).toEqual([
        { type: "reply_started", replyId },
        { type: "text_delta", text: "お昼はしっかり" },
        { type: "text_delta", text: "食べられていますね。" },
        { type: "replied", replyId },
      ]);
    });
  });

  describe("返事の試みが流している途中で失敗し、やり直しで作れたとき", () => {
    let response: Response;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new ConversationProviderError({ errorType: "overloaded_error" }),
        textDeltasBeforeFailure: ["お昼は"],
      });
      const sentTextId = await sendText();
      response = await watchReplyStream(sessionToken, sentTextId);
      await runEstimationAlarm(accountId);
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: {
          body: "お昼は軽めでしたね。",
          mealIds: [],
          textDeltas: ["お昼は", "軽めでしたね。"],
        },
      });
      clock.advance(10 * 60_000);
      await runEstimationAlarm(accountId);
    });

    test("流した分を捨てる知らせを送り、同じ ID のまま初めから流し直すこと", async () => {
      const [replyId] = await readGenerationIds();
      expect(await readReplyStreamEvents(response)).toEqual([
        { type: "reply_started", replyId },
        { type: "text_delta", text: "お昼は" },
        { type: "text_discarded" },
        { type: "text_delta", text: "お昼は" },
        { type: "text_delta", text: "軽めでしたね。" },
        { type: "replied", replyId },
      ]);
    });
  });

  describe("流す前に試みが失敗したとき", () => {
    let response: Response;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new ConversationProviderTimedOutError(),
      });
      const sentTextId = await sendText();
      response = await watchReplyStream(sessionToken, sentTextId);
      await runEstimationAlarm(accountId);
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: { body: "お疲れさまです。", mealIds: [] },
      });
      clock.advance(10 * 60_000);
      await runEstimationAlarm(accountId);
    });

    test("捨てる知らせを送らないこと", async () => {
      const [replyId] = await readGenerationIds();
      expect(await readReplyStreamEvents(response)).toEqual([
        { type: "reply_started", replyId },
        { type: "text_delta", text: "お疲れさまです。" },
        { type: "replied", replyId },
      ]);
    });
  });

  describe("食事と読み分けたとき", () => {
    let response: Response;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "meal" });
      const sentTextId = await sendText();
      response = await watchReplyStream(sessionToken, sentTextId);
      await runEstimationAlarm(accountId);
    });

    test("食事と読み分けた結果を送って閉じること", async () => {
      expect(await readReplyStreamEvents(response)).toEqual([{ type: "classified_as_meal" }]);
    });
  });

  describe("その日の返事の回数を使い切っていたとき", () => {
    let response: Response;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      await insertCountedReplyRequests(
        accountId,
        new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Tokyo" }).format(Date.now()),
        { generated: 20, halted: 0 },
      );
      const sentTextId = await sendText();
      response = await watchReplyStream(sessionToken, sentTextId);
      await runEstimationAlarm(accountId);
    });

    test("回数切れの結果を送って閉じること", async () => {
      expect(await readReplyStreamEvents(response)).toEqual([{ type: "reply_halted" }]);
    });
  });

  describe("提供元が 400 を返したとき", () => {
    let response: Response;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new ConversationProviderBadRequestError({ errorType: "invalid_request_error" }),
      });
      const sentTextId = await sendText();
      response = await watchReplyStream(sessionToken, sentTextId);
      await runEstimationAlarm(accountId);
    });

    test("返事の ID のあとに、作れなかった結果を理由つきで送って閉じること", async () => {
      const [replyId] = await readGenerationIds();
      expect(await readReplyStreamEvents(response)).toEqual([
        { type: "reply_started", replyId },
        { type: "reply_failed", failureReason: "bad_request" },
      ]);
    });
  });

  describe("返事を作り終えてからつないだとき", () => {
    let response: Response;
    beforeEach(async () => {
      mockCreateConversationProviderOk({ classification: "conversation" });
      const sentTextId = await sendText();
      await runEstimationAlarm(accountId);
      response = await watchReplyStream(sessionToken, sentTextId);
    });

    test("返事ありの結果だけを送って閉じること", async () => {
      const [replyId] = await readGenerationIds();
      expect(await readReplyStreamEvents(response)).toEqual([{ type: "replied", replyId }]);
    });
  });

  describe("やり直しを待っているあいだにつないだとき", () => {
    let response: Response;
    beforeEach(async () => {
      mockCreateConversationProviderError({
        failingCall: "generate_reply",
        error: new ConversationProviderTimedOutError(),
      });
      const sentTextId = await sendText();
      await runEstimationAlarm(accountId);
      response = await watchReplyStream(sessionToken, sentTextId);
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: { body: "お疲れさまです。", mealIds: [] },
      });
      clock.advance(10 * 60_000);
      await runEstimationAlarm(accountId);
    });

    test("はじめに返事の ID を送り、次の試みのできた分を流すこと", async () => {
      const [replyId] = await readGenerationIds();
      expect(await readReplyStreamEvents(response)).toEqual([
        { type: "reply_started", replyId },
        { type: "text_delta", text: "お疲れさまです。" },
        { type: "replied", replyId },
      ]);
    });
  });

  describe("返事を作る前に端末が切れたとき", () => {
    let sentTextId: string;
    beforeEach(async () => {
      mockCreateConversationProviderOk({
        classification: "conversation",
        reply: {
          body: "お昼はしっかり食べられていますね。",
          mealIds: [],
          textDeltas: ["お昼はしっかり", "食べられていますね。"],
        },
      });
      sentTextId = await sendText();
      const response = await watchReplyStream(sessionToken, sentTextId);
      await response.body?.cancel();
      await runEstimationAlarm(accountId);
    });

    test("最後まで作り、返事を記録として届けること", async () => {
      expect(await pullRecordsOf("ai_utterance")).toEqual([
        expect.objectContaining({ sentTextId, body: "お昼はしっかり食べられていますね。" }),
      ]);
    });
  });

  describe("知らない送った文章につないだとき", () => {
    let response: Response;
    beforeEach(async () => {
      response = await watchReplyStream(sessionToken, generateRecordId());
    });

    test("404 を返すこと", () => {
      expect(response.status).toBe(404);
    });
  });
});
