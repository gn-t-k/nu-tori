import type Anthropic from "@anthropic-ai/sdk";
import { beforeEach, describe, expect, test } from "vitest";
import { stubAnthropicApi } from "../../src/estimation/durable-object/create-estimation-provider/testing/stub-anthropic-api";
import { checkEvalKey } from "./index";

describe("評価の鍵で呼べるかを確かめる", () => {
  describe("呼べたとき", () => {
    let client: Anthropic;
    let requests: ReturnType<typeof stubAnthropicApi>["requests"];
    beforeEach(() => {
      const stub = stubAnthropicApi(async () =>
        Response.json({
          id: "msg_1",
          type: "message",
          role: "assistant",
          model: "claude-haiku-5-5",
          content: [{ type: "text", text: "." }],
          stop_reason: "max_tokens",
          stop_sequence: null,
          usage: { input_tokens: 8, output_tokens: 1 },
        }),
      );
      client = stub.client;
      requests = stub.requests;
    });

    test("成功で返すこと", async () => {
      expect(await checkEvalKey(client)).toBeSuccess();
    });

    test("出力を 1 トークンに絞って呼ぶこと", async () => {
      await checkEvalKey(client);

      expect(requests).toMatchObject([{ body: { max_tokens: 1 } }]);
    });
  });

  describe("月の支出の上限に達して 400 が返ったとき", () => {
    let client: Anthropic;
    beforeEach(() => {
      client = stubAnthropicApi(async () =>
        Response.json(
          {
            type: "error",
            error: {
              type: "invalid_request_error",
              message: "You have reached your specified workspace API usage limits.",
            },
          },
          { status: 400 },
        ),
      ).client;
    });

    test("400 の失敗で返すこと", async () => {
      expect(await checkEvalKey(client)).toBeFailure((error) => {
        expect(error.name).toBe("LlmCallBadRequestError");
      });
    });
  });
});
