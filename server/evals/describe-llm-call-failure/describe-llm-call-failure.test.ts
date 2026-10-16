import { R } from "@praha/byethrow";
import { beforeEach, describe, expect, test } from "vitest";
import { catchAnthropicFailure } from "../../src/durable-object/anthropic/catch-anthropic-failure";
import { LlmCallTimedOutError } from "../../src/domain/llm-call-timed-out-error";
import { stubAnthropicApi } from "../../src/estimation/durable-object/create-estimation-provider/testing/stub-anthropic-api";
import { describeLlmCallFailure } from "./index";

// 本物と同じ道（SDK の失敗を catchAnthropicFailure で写す）で、失敗を作る
const failWith = async (response: Response) => {
  const { client } = stubAnthropicApi(async () => response);
  const called = await catchAnthropicFailure(
    client.messages.create({ model: "claude-haiku-5-5", max_tokens: 1, messages: [] }),
  );
  if (R.isSuccess(called)) {
    throw new Error("呼び出しが成功した");
  }
  return called.error;
};

describe("LLM の呼び出しの失敗を、評価の結果に出す文にする", () => {
  describe("400 の応答の本文にエラーの種類と文があるとき", () => {
    let error: Parameters<typeof describeLlmCallFailure>[0];
    beforeEach(async () => {
      error = await failWith(
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
      );
    });

    test("名前に、応答の本文のエラーの種類と文を添えること", () => {
      expect(describeLlmCallFailure(error)).toBe(
        "LlmCallBadRequestError（invalid_request_error: You have reached your specified workspace API usage limits.）",
      );
    });
  });

  describe("応答の本文にエラーの文が無いとき", () => {
    let error: Parameters<typeof describeLlmCallFailure>[0];
    beforeEach(async () => {
      error = await failWith(new Response("Bad Gateway", { status: 502 }));
    });

    test("名前に、エラーの種類だけを添えること", () => {
      expect(describeLlmCallFailure(error)).toBe("LlmCallError（http_502）");
    });
  });

  describe("エラーの種類を持たない失敗のとき", () => {
    let error: Parameters<typeof describeLlmCallFailure>[0];
    beforeEach(() => {
      error = new LlmCallTimedOutError();
    });

    test("名前だけにすること", () => {
      expect(describeLlmCallFailure(error)).toBe("LlmCallTimedOutError");
    });
  });
});
