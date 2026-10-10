import { APIError } from "@anthropic-ai/sdk";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { replyWithError } from "../../../estimation/durable-object/create-estimation-provider/testing/reply-with-error";
import { replyWithText } from "../../../estimation/durable-object/create-estimation-provider/testing/reply-with-text";
import { stubAnthropicApi } from "../../../estimation/durable-object/create-estimation-provider/testing/stub-anthropic-api";
import { recordIdSchema } from "../../../domain/record-id";
import type { ConversationProvider } from "../../domain/conversation-provider";
import type { ReplyContext } from "../../domain/reply-context";
import { createAnthropicConversationProvider } from "./create-anthropic-conversation-provider";
import { replyWithTextStream } from "./testing/reply-with-text-stream";

// "account-1" の SHA-256（16 進）。ハッシュの正しさは、独立に計算した値で確かめる
const hashOfAccount1 = "07e998012c1137decdf3efbbb1c3ee6d79b015638cbc197bdbcce1875de4faad";

describe("createAnthropicConversationProvider", () => {
  describe("読み分け", () => {
    describe("食事と答えたとき", () => {
      let provider: ConversationProvider;
      let request: ClassificationRequest;
      let requests: ReturnType<typeof stubAnthropicApi>["requests"];
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(JSON.stringify({ label: "meal" }), {
            usage: { input_tokens: 420, output_tokens: 6 },
          }),
        );
        requests = stub.requests;
        provider = createAnthropicConversationProvider(stub.client, "account-1");
        request = { body: "お昼に親子丼" };
      });

      test("食事と、使ったトークンを返すこと", async () => {
        const result = await provider.classifySentText(request);

        expect(result).toBeSuccess((reply) => {
          expect(reply).toEqual({ label: "meal", usage: { inputTokens: 420, outputTokens: 6 } });
        });
      });

      test("Haiku 5.5 に、思考を切り、アカウント ID のハッシュを添えて、文章をユーザーのメッセージで渡すこと", async () => {
        await provider.classifySentText(request);

        expect(requests.map(({ url, apiKey, body }) => ({ url, apiKey, body }))).toEqual([
          {
            url: "https://api.anthropic.com/v1/messages",
            apiKey: "test-anthropic-api-key",
            body: expect.objectContaining({
              model: "claude-haiku-5-5",
              thinking: { type: "disabled" },
              metadata: { user_id: hashOfAccount1 },
              messages: [{ role: "user", content: "お昼に親子丼" }],
              output_config: expect.objectContaining({
                effort: "low",
                format: expect.objectContaining({ type: "json_schema" }),
              }),
            }),
          },
        ]);
      });
    });

    describe("会話と答えたとき", () => {
      let provider: ConversationProvider;
      let request: ClassificationRequest;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(JSON.stringify({ label: "conversation" })),
        );
        provider = createAnthropicConversationProvider(stub.client, "account-1");
        request = { body: "今日は何を食べようかな" };
      });

      test("その答えを返すこと", async () => {
        const result = await provider.classifySentText(request);

        expect(result).toBeSuccess((reply) => {
          expect(reply.label).toBe("conversation");
        });
      });
    });

    describe("決めかねると答えたとき", () => {
      let provider: ConversationProvider;
      let request: ClassificationRequest;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(JSON.stringify({ label: "unsure" })),
        );
        provider = createAnthropicConversationProvider(stub.client, "account-1");
        request = { body: "今日は何を食べようかな" };
      });

      test("その答えを返すこと", async () => {
        const result = await provider.classifySentText(request);

        expect(result).toBeSuccess((reply) => {
          expect(reply.label).toBe("unsure");
        });
      });
    });

    describe("応答が JSON でないとき", () => {
      let provider: ConversationProvider;
      let request: ClassificationRequest;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () => replyWithText("食事です"));
        provider = createAnthropicConversationProvider(stub.client, "account-1");
        request = { body: "お昼に親子丼" };
      });

      test("invalid_response の失敗で返すこと", async () => {
        const result = await provider.classifySentText(request);

        expect(result).toBeFailure((error) => {
          expect({ name: error.name, errorType: error.errorType }).toEqual({
            name: "ConversationProviderError",
            errorType: "invalid_response",
          });
        });
      });
    });

    describe("知らない答えのとき", () => {
      let provider: ConversationProvider;
      let request: ClassificationRequest;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(JSON.stringify({ label: "snack" })),
        );
        provider = createAnthropicConversationProvider(stub.client, "account-1");
        request = { body: "お昼に親子丼" };
      });

      test("invalid_response の失敗で返すこと", async () => {
        const result = await provider.classifySentText(request);

        expect(result).toBeFailure((error) => {
          expect({ name: error.name, errorType: error.errorType }).toEqual({
            name: "ConversationProviderError",
            errorType: "invalid_response",
          });
        });
      });
    });

    describe("出力の上限で途中で切れたとき", () => {
      let provider: ConversationProvider;
      let request: ClassificationRequest;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText('{"label":', { stopReason: "max_tokens" }),
        );
        provider = createAnthropicConversationProvider(stub.client, "account-1");
        request = { body: "お昼に親子丼" };
      });

      test("invalid_response の失敗で返すこと", async () => {
        const result = await provider.classifySentText(request);

        expect(result).toBeFailure((error) => {
          expect({ name: error.name, errorType: error.errorType }).toEqual({
            name: "ConversationProviderError",
            errorType: "invalid_response",
          });
        });
      });
    });

    describe("安全のために答えなかったとき", () => {
      let provider: ConversationProvider;
      let request: ClassificationRequest;
      beforeEach(() => {
        const stub = stubAnthropicApi(async () => replyWithText("", { stopReason: "refusal" }));
        provider = createAnthropicConversationProvider(stub.client, "account-1");
        request = { body: "お昼に親子丼" };
      });

      test("invalid_response の失敗で返すこと", async () => {
        const result = await provider.classifySentText(request);

        expect(result).toBeFailure((error) => {
          expect({ name: error.name, errorType: error.errorType }).toEqual({
            name: "ConversationProviderError",
            errorType: "invalid_response",
          });
        });
      });
    });

    describe("提供元の呼び出しが失敗したとき", () => {
      describe("HTTP 400 のとき", () => {
        let provider: ConversationProvider;
        let request: ClassificationRequest;
        beforeEach(() => {
          // 前払いのクレジットが尽きたときも 400 で返る
          const stub = stubAnthropicApi(async () =>
            replyWithError(400, "invalid_request_error", "Your credit balance is too low"),
          );
          provider = createAnthropicConversationProvider(stub.client, "account-1");
          request = { body: "お昼に親子丼" };
        });

        test("提供元のエラーの種類と、応答のエラーを持つ失敗で返すこと", async () => {
          const result = await provider.classifySentText(request);

          expect(result).toBeFailure((error) => {
            expect({
              errorType: error.errorType,
              causeStatus: error.cause instanceof APIError ? error.cause.status : undefined,
            }).toEqual({ errorType: "invalid_request_error", causeStatus: 400 });
          });
        });
      });

      describe("HTTP 529（過負荷）のとき", () => {
        let provider: ConversationProvider;
        let request: ClassificationRequest;
        beforeEach(() => {
          const stub = stubAnthropicApi(async () =>
            replyWithError(529, "overloaded_error", "Overloaded"),
          );
          provider = createAnthropicConversationProvider(stub.client, "account-1");
          request = { body: "お昼に親子丼" };
        });

        test("提供元のエラーの種類と、応答のエラーを持つ失敗で返すこと", async () => {
          const result = await provider.classifySentText(request);

          expect(result).toBeFailure((error) => {
            expect({
              errorType: error.errorType,
              causeStatus: error.cause instanceof APIError ? error.cause.status : undefined,
            }).toEqual({ errorType: "overloaded_error", causeStatus: 529 });
          });
        });
      });

      describe("エラーの種類が応答に無いとき", () => {
        let provider: ConversationProvider;
        let request: ClassificationRequest;
        beforeEach(() => {
          const stub = stubAnthropicApi(async () => new Response("Bad Gateway", { status: 502 }));
          provider = createAnthropicConversationProvider(stub.client, "account-1");
          request = { body: "お昼に親子丼" };
        });

        test("提供元のエラーの種類と、応答のエラーを持つ失敗で返すこと", async () => {
          const result = await provider.classifySentText(request);

          expect(result).toBeFailure((error) => {
            expect({
              errorType: error.errorType,
              causeStatus: error.cause instanceof APIError ? error.cause.status : undefined,
            }).toEqual({ errorType: "http_502", causeStatus: 502 });
          });
        });
      });

      describe("つなげなかったとき", () => {
        let provider: ConversationProvider;
        let request: ClassificationRequest;
        beforeEach(() => {
          const stub = stubAnthropicApi(async () => {
            throw new TypeError("fetch failed");
          });
          provider = createAnthropicConversationProvider(stub.client, "account-1");
          request = { body: "お昼に親子丼" };
        });

        test("connection_error の失敗で返すこと", async () => {
          const result = await provider.classifySentText(request);

          expect(result).toBeFailure((error) => {
            expect(error.errorType).toBe("connection_error");
          });
        });
      });

      describe("呼び出しの時間の上限を超えたとき", () => {
        let provider: ConversationProvider;
        let request: ClassificationRequest;
        beforeEach(() => {
          vi.useFakeTimers();
          const stub = stubAnthropicApi(() => new Promise(() => {}));
          provider = createAnthropicConversationProvider(stub.client, "account-1");
          request = { body: "お昼に親子丼" };
        });

        afterEach(() => {
          vi.useRealTimers();
        });

        test("30 秒で、timed_out の失敗で返すこと", async () => {
          const pending = provider.classifySentText(request);

          await vi.advanceTimersByTimeAsync(30_000);

          expect(await pending).toBeFailure((error) => {
            expect(error.errorType).toBe("timed_out");
          });
        });
      });
    });
  });

  describe("返事", () => {
    describe("本文と指し示す食事を流して答えたとき", () => {
      let provider: ConversationProvider;
      let requests: ReturnType<typeof stubAnthropicApi>["requests"];
      beforeEach(() => {
        const stub = stubAnthropicApi(async (signal) =>
          replyWithTextStream(
            ['{"body":"お昼の', "親子丼、", `いいですね。","mealIds":["${mealId}"]}`],
            {
              type: "stop",
              stopReason: "end_turn",
              usage: { input_tokens: 2400, output_tokens: 180 },
            },
            signal,
          ),
        );
        requests = stub.requests;
        provider = createAnthropicConversationProvider(stub.client, "account-1");
      });

      test("本文と、指し示す食事と、使ったトークンを返すこと", async () => {
        const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

        expect(result).toBeSuccess((reply) => {
          expect(reply).toEqual({
            body: "お昼の親子丼、いいですね。",
            mealIds: [mealId],
            usage: { inputTokens: 2400, outputTokens: 180 },
          });
        });
      });

      test("Sonnet 5.5 に、思考を切り、アカウント ID のハッシュを添えて、流す形で頼むこと", async () => {
        await provider.generateReply({ context, onText: () => {} }, neverEnds());

        expect(requests).toEqual([
          {
            url: "https://api.anthropic.com/v1/messages",
            apiKey: "test-anthropic-api-key",
            body: expect.objectContaining({
              model: "claude-sonnet-5-5",
              thinking: { type: "between_tools" },
              metadata: { user_id: hashOfAccount1 },
              stream: true,
              output_config: expect.objectContaining({
                format: expect.objectContaining({ type: "json_schema" }),
              }),
            }),
          },
        ]);
      });

      test("指示を system に置き、文脈の窓・記録の値・新しい発言の順にユーザーのメッセージで渡し、窓のあとにキャッシュの印を付けること", async () => {
        await provider.generateReply({ context, onText: () => {} }, neverEnds());

        expect(requests[0]?.body).toMatchObject({
          system: expect.stringContaining("返事"),
          messages: [
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text: expect.stringContaining("07:00 ユーザー: 朝ごはん何がいい？"),
                  cache_control: { type: "ephemeral" },
                },
                {
                  type: "text",
                  text: expect.stringContaining("親子丼（1 杯）"),
                },
                {
                  type: "text",
                  text: expect.stringMatching(/13:00 ユーザー: お昼は親子丼にしたよ$/),
                },
              ],
            },
          ],
        });
        expect(requests[0]?.body).not.toHaveProperty("messages.0.content.1.cache_control");
        expect(requests[0]?.body).not.toHaveProperty("messages.0.content.2.cache_control");
      });
    });

    describe("本文を少しずつ流したとき", () => {
      let provider: ConversationProvider;
      let texts: string[];
      beforeEach(() => {
        const stub = stubAnthropicApi(async (signal) =>
          replyWithTextStream(
            [
              '{"bo',
              'dy":"こんに',
              "ちは。\\",
              "n「親子丼」は\\",
              '"良い\\"',
              "です\\u30",
              "42\\ud83c",
              "\\udf5a",
              '","mealIds":[]}',
            ],
            endTurn,
            signal,
          ),
        );
        provider = createAnthropicConversationProvider(stub.client, "account-1");
        texts = [];
      });

      test("JSON の外側を除き、エスケープを戻した本文のできた分を、できた順に onText に渡すこと", async () => {
        const result = await provider.generateReply(
          { context, onText: (text) => texts.push(text) },
          neverEnds(),
        );

        expect(texts).toEqual(["こんに", "ちは。", "\n「親子丼」は", '"良い"', "です", "あ", "🍚"]);
        expect(result).toBeSuccess((reply) => {
          expect(reply.body).toBe(texts.join(""));
        });
      });
    });

    describe("JSON が本文から始まらないとき", () => {
      let provider: ConversationProvider;
      let texts: string[];
      beforeEach(() => {
        const stub = stubAnthropicApi(async (signal) =>
          replyWithTextStream(
            [`{"mealIds":["${mealId}"],`, '"body":"親子丼、', 'いいですね。"}'],
            endTurn,
            signal,
          ),
        );
        provider = createAnthropicConversationProvider(stub.client, "account-1");
        texts = [];
      });

      test("読み終えてから、本文をまとめて onText に渡すこと", async () => {
        await provider.generateReply({ context, onText: (text) => texts.push(text) }, neverEnds());

        expect(texts).toEqual(["親子丼、いいですね。"]);
      });
    });

    describe("出力の上限で途中で切れたとき", () => {
      let provider: ConversationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async (signal) =>
          replyWithTextStream(
            ['{"body":"お昼の親子丼'],
            {
              type: "stop",
              stopReason: "max_tokens",
              usage: { input_tokens: 2400, output_tokens: 4096 },
            },
            signal,
          ),
        );
        provider = createAnthropicConversationProvider(stub.client, "account-1");
      });

      test("使ったトークンを持つ、読めない応答の失敗で返すこと", async () => {
        const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

        expect(result).toBeFailure((error) => {
          expect(error).toMatchObject({
            name: "ConversationProviderInvalidResponseError",
            usage: { inputTokens: 2400, outputTokens: 4096 },
          });
        });
      });
    });

    describe("安全のために答えなかったとき", () => {
      let provider: ConversationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async (signal) =>
          replyWithTextStream(
            [],
            {
              type: "stop",
              stopReason: "refusal",
              usage: { input_tokens: 2400, output_tokens: 4096 },
            },
            signal,
          ),
        );
        provider = createAnthropicConversationProvider(stub.client, "account-1");
      });

      test("使ったトークンを持つ、読めない応答の失敗で返すこと", async () => {
        const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

        expect(result).toBeFailure((error) => {
          expect(error).toMatchObject({
            name: "ConversationProviderInvalidResponseError",
            usage: { inputTokens: 2400, outputTokens: 4096 },
          });
        });
      });
    });

    describe("応答の形が違うとき", () => {
      let provider: ConversationProvider;
      beforeEach(() => {
        const stub = stubAnthropicApi(async (signal) =>
          replyWithTextStream(
            ['{"body":"はい","mealIds":["meal-1"]}'],
            {
              type: "stop",
              stopReason: "end_turn",
              usage: { input_tokens: 2400, output_tokens: 4096 },
            },
            signal,
          ),
        );
        provider = createAnthropicConversationProvider(stub.client, "account-1");
      });

      test("使ったトークンを持つ、読めない応答の失敗で返すこと", async () => {
        const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

        expect(result).toBeFailure((error) => {
          expect(error).toMatchObject({
            name: "ConversationProviderInvalidResponseError",
            usage: { inputTokens: 2400, outputTokens: 4096 },
          });
        });
      });
    });

    describe("提供元の呼び出しが失敗したとき", () => {
      describe("HTTP 400 のとき", () => {
        let provider: ConversationProvider;
        beforeEach(() => {
          const stub = stubAnthropicApi(async () =>
            replyWithError(400, "invalid_request_error", "Workspace spend limit reached"),
          );
          provider = createAnthropicConversationProvider(stub.client, "account-1");
        });

        test("状態コードで見分け、提供元のエラーの種類と応答のエラーを持つ 400 の失敗で返すこと", async () => {
          const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

          expect(result).toBeFailure((error) => {
            expect({
              name: error.name,
              errorType: "errorType" in error ? error.errorType : undefined,
              causeStatus: error.cause instanceof APIError ? error.cause.status : undefined,
            }).toEqual({
              name: "ConversationProviderBadRequestError",
              errorType: "invalid_request_error",
              causeStatus: 400,
            });
          });
        });
      });

      describe("HTTP 529（過負荷）のとき", () => {
        let provider: ConversationProvider;
        beforeEach(() => {
          const stub = stubAnthropicApi(async () =>
            replyWithError(529, "overloaded_error", "Overloaded"),
          );
          provider = createAnthropicConversationProvider(stub.client, "account-1");
        });

        test("提供元のエラーの種類を持つ失敗で返すこと", async () => {
          const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

          expect(result).toBeFailure((error) => {
            expect(error).toMatchObject({
              name: "ConversationProviderError",
              errorType: "overloaded_error",
            });
          });
        });
      });

      describe("エラーの種類が応答に無いとき", () => {
        let provider: ConversationProvider;
        beforeEach(() => {
          const stub = stubAnthropicApi(async () => new Response("Bad Gateway", { status: 502 }));
          provider = createAnthropicConversationProvider(stub.client, "account-1");
        });

        test("提供元のエラーの種類を持つ失敗で返すこと", async () => {
          const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

          expect(result).toBeFailure((error) => {
            expect(error).toMatchObject({
              name: "ConversationProviderError",
              errorType: "http_502",
            });
          });
        });
      });

      describe("流している途中でエラーの出来事が届いたとき", () => {
        let provider: ConversationProvider;
        beforeEach(() => {
          const stub = stubAnthropicApi(async (signal) =>
            replyWithTextStream(
              ['{"body":"お昼の'],
              { type: "error", errorType: "overloaded_error" },
              signal,
            ),
          );
          provider = createAnthropicConversationProvider(stub.client, "account-1");
        });

        test("提供元のエラーの種類を持つ失敗で返すこと", async () => {
          const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

          expect(result).toBeFailure((error) => {
            expect(error).toMatchObject({
              name: "ConversationProviderError",
              errorType: "overloaded_error",
            });
          });
        });
      });

      describe("流れが終わりの出来事なしに閉じたとき", () => {
        let provider: ConversationProvider;
        beforeEach(() => {
          const stub = stubAnthropicApi(async (signal) =>
            replyWithTextStream(['{"body":"お昼の'], { type: "cut" }, signal),
          );
          provider = createAnthropicConversationProvider(stub.client, "account-1");
        });

        test("提供元のエラーの種類を持つ失敗で返すこと", async () => {
          const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

          expect(result).toBeFailure((error) => {
            expect(error).toMatchObject({
              name: "ConversationProviderError",
              errorType: "stream_ended",
            });
          });
        });
      });

      describe("つなげなかったとき", () => {
        let provider: ConversationProvider;
        beforeEach(() => {
          const stub = stubAnthropicApi(async () => {
            throw new TypeError("fetch failed");
          });
          provider = createAnthropicConversationProvider(stub.client, "account-1");
        });

        test("提供元のエラーの種類を持つ失敗で返すこと", async () => {
          const result = await provider.generateReply({ context, onText: () => {} }, neverEnds());

          expect(result).toBeFailure((error) => {
            expect(error).toMatchObject({
              name: "ConversationProviderError",
              errorType: "connection_error",
            });
          });
        });
      });

      describe("頼む前に試みの時間の上限（signal）が切れていたとき", () => {
        let provider: ConversationProvider;
        let signal: AbortSignal;
        beforeEach(() => {
          const stub = stubAnthropicApi(() => new Promise(() => {}));
          provider = createAnthropicConversationProvider(stub.client, "account-1");
          signal = AbortSignal.abort();
        });

        test("時間切れの失敗で返すこと", async () => {
          const result = await provider.generateReply({ context, onText: () => {} }, signal);

          expect(result).toBeFailure((error) => {
            expect(error.name).toBe("ConversationProviderTimedOutError");
          });
        });
      });

      describe("流している途中で試みの時間の上限（signal）が切れたとき", () => {
        let provider: ConversationProvider;
        let controller: AbortController;
        beforeEach(() => {
          const stub = stubAnthropicApi(async (signal) =>
            replyWithTextStream(['{"body":"お昼の'], { type: "hang" }, signal),
          );
          provider = createAnthropicConversationProvider(stub.client, "account-1");
          controller = new AbortController();
        });

        test("時間切れの失敗で返すこと", async () => {
          const result = await provider.generateReply(
            { context, onText: () => controller.abort() },
            controller.signal,
          );

          expect(result).toBeFailure((error) => {
            expect(error.name).toBe("ConversationProviderTimedOutError");
          });
        });
      });
    });
  });
});

type ClassificationRequest = Parameters<ConversationProvider["classifySentText"]>[0];

const endTurn = {
  type: "stop",
  stopReason: "end_turn",
  usage: { input_tokens: 2400, output_tokens: 180 },
} as const;

const neverEnds = () => new AbortController().signal;

const mealId = recordIdSchema.parse("00000000-0000-4000-8000-000000000004");

const context: ReplyContext = {
  window: [
    { type: "user_utterance", at: "2026-10-10T07:00", body: "朝ごはん何がいい？" },
    { type: "ai_utterance", at: "2026-10-10T07:00", body: "たんぱく質を足しましょう" },
    {
      type: "meal_recorded",
      at: "2026-10-10T12:40",
      mealId,
      eatenAt: "2026-10-10T12:30",
      dishNames: ["親子丼"],
    },
  ],
  structuredValues: {
    sentAt: { at: "2026-10-10T13:00", dayOfWeek: "saturday" },
    todayMeals: [
      {
        mealId,
        eatenAt: "2026-10-10T12:30",
        estimation: "settled",
        dishes: [
          {
            name: "親子丼",
            quantity: { value: 1, unit: "杯" },
            nutrients: {
              energyKcal: { type: "exactly", value: 650 },
              proteinG: { type: "exactly", value: 30 },
              fatG: { type: "exactly", value: 18 },
              carbohydrateG: { type: "exactly", value: 90 },
            },
          },
        ],
      },
    ],
    todayNutrients: {
      energyKcal: { type: "exactly", value: 650 },
      proteinG: { type: "exactly", value: 30 },
      fatG: { type: "exactly", value: 18 },
      carbohydrateG: { type: "exactly", value: 90 },
    },
    yesterdayMeals: [],
    previousDays: [],
    weeklyWeightTrend: [],
    lastWeightRecord: undefined,
  },
  newUtterance: { at: "2026-10-10T13:00", body: "お昼は親子丼にしたよ" },
};
