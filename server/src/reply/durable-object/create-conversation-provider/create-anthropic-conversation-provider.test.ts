import { APIError } from "@anthropic-ai/sdk";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";
import { replyWithError } from "../../../estimation/durable-object/create-estimation-provider/testing/reply-with-error";
import { replyWithText } from "../../../estimation/durable-object/create-estimation-provider/testing/reply-with-text";
import { stubAnthropicApi } from "../../../estimation/durable-object/create-estimation-provider/testing/stub-anthropic-api";
import type { ConversationProvider } from "../../domain/conversation-provider";
import { createAnthropicConversationProvider } from "./create-anthropic-conversation-provider";

// "account-1" の SHA-256（16 進）。ハッシュの正しさは、独立に計算した値で確かめる
const hashOfAccount1 = "07e998012c1137decdf3efbbb1c3ee6d79b015638cbc197bdbcce1875de4faad";

describe("createAnthropicConversationProvider", () => {
  describe("読み分け", () => {
    describe("食事と答えたとき", () => {
      let provider: ConversationProvider;
      let requests: ReturnType<typeof stubAnthropicApi>["requests"];
      beforeEach(() => {
        const stub = stubAnthropicApi(async () =>
          replyWithText(JSON.stringify({ label: "meal" }), {
            usage: { input_tokens: 420, output_tokens: 6 },
          }),
        );
        requests = stub.requests;
        provider = createAnthropicConversationProvider(stub.client, "account-1");
      });

      test("食事と、使ったトークンを返すこと", async () => {
        const result = await provider.classifySentText({ body: "お昼に親子丼" });

        expect(result).toBeSuccess((reply) => {
          expect(reply).toEqual({ label: "meal", usage: { inputTokens: 420, outputTokens: 6 } });
        });
      });

      test("Haiku 5.5 に、思考を切り、アカウント ID のハッシュを添えて、文章をユーザーのメッセージで渡すこと", async () => {
        await provider.classifySentText({ body: "お昼に親子丼" });

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

    describe.for([
      { name: "会話と答えたとき", label: "conversation" },
      { name: "決めかねると答えたとき", label: "unsure" },
    ] as const)("$name", ({ label }) => {
      test("その答えを返すこと", async () => {
        const stub = stubAnthropicApi(async () => replyWithText(JSON.stringify({ label })));
        const provider = createAnthropicConversationProvider(stub.client, "account-1");

        const result = await provider.classifySentText({ body: "今日は何を食べようかな" });

        expect(result).toBeSuccess((reply) => {
          expect(reply.label).toBe(label);
        });
      });
    });

    describe.for([
      { name: "応答が JSON でないとき", reply: () => replyWithText("食事です") },
      {
        name: "知らない答えのとき",
        reply: () => replyWithText(JSON.stringify({ label: "snack" })),
      },
      {
        name: "出力の上限で途中で切れたとき",
        reply: () => replyWithText('{"label":', { stopReason: "max_tokens" }),
      },
      {
        name: "安全のために答えなかったとき",
        reply: () => replyWithText("", { stopReason: "refusal" }),
      },
    ])("$name", ({ reply }) => {
      test("invalid_response の失敗で返すこと", async () => {
        const stub = stubAnthropicApi(async () => reply());
        const provider = createAnthropicConversationProvider(stub.client, "account-1");

        const result = await provider.classifySentText({ body: "お昼に親子丼" });

        expect(result).toBeFailure((error) => {
          expect({ name: error.name, errorType: error.errorType }).toEqual({
            name: "ConversationProviderError",
            errorType: "invalid_response",
          });
        });
      });
    });

    describe("提供元の呼び出しが失敗したとき", () => {
      describe.for([
        {
          // 前払いのクレジットが尽きたときも 400 で返る
          name: "HTTP 400 のとき",
          reply: () =>
            replyWithError(400, "invalid_request_error", "Your credit balance is too low"),
          errorType: "invalid_request_error",
        },
        {
          name: "HTTP 529（過負荷）のとき",
          reply: () => replyWithError(529, "overloaded_error", "Overloaded"),
          errorType: "overloaded_error",
        },
        {
          name: "エラーの種類が応答に無いとき",
          reply: () => new Response("Bad Gateway", { status: 502 }),
          errorType: "http_502",
        },
      ])("$name", ({ reply, errorType }) => {
        test("提供元のエラーの種類と、応答のエラーを持つ失敗で返すこと", async () => {
          const stub = stubAnthropicApi(async () => reply());
          const provider = createAnthropicConversationProvider(stub.client, "account-1");

          const result = await provider.classifySentText({ body: "お昼に親子丼" });

          expect(result).toBeFailure((error) => {
            expect({
              errorType: error.errorType,
              causeStatus: error.cause instanceof APIError ? error.cause.status : undefined,
            }).toEqual({ errorType, causeStatus: reply().status });
          });
        });
      });

      describe("つなげなかったとき", () => {
        test("connection_error の失敗で返すこと", async () => {
          const stub = stubAnthropicApi(async () => {
            throw new TypeError("fetch failed");
          });
          const provider = createAnthropicConversationProvider(stub.client, "account-1");

          const result = await provider.classifySentText({ body: "お昼に親子丼" });

          expect(result).toBeFailure((error) => {
            expect(error.errorType).toBe("connection_error");
          });
        });
      });

      describe("呼び出しの時間の上限を超えたとき", () => {
        beforeEach(() => {
          vi.useFakeTimers();
        });

        afterEach(() => {
          vi.useRealTimers();
        });

        test("30 秒で、timed_out の失敗で返すこと", async () => {
          const stub = stubAnthropicApi(() => new Promise(() => {}));
          const provider = createAnthropicConversationProvider(stub.client, "account-1");
          const pending = provider.classifySentText({ body: "お昼に親子丼" });

          await vi.advanceTimersByTimeAsync(30_000);

          expect(await pending).toBeFailure((error) => {
            expect(error.errorType).toBe("timed_out");
          });
        });
      });
    });
  });
});
