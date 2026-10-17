import { APIError } from "@anthropic-ai/sdk";
import { match } from "ts-pattern";
import { z } from "zod";
import type { LlmCallBadRequestError } from "../../src/domain/llm-call-bad-request-error";
import type { LlmCallError } from "../../src/domain/llm-call-error";
import type { LlmCallInvalidResponseError } from "../../src/domain/llm-call-invalid-response-error";
import type { LlmCallTimedOutError } from "../../src/domain/llm-call-timed-out-error";

// LLM の呼び出しの失敗を、評価の結果に出す1行にする（#565）。
// 400 は月の支出の上限に当たったときも同じ失敗になり、名前だけでは理由が見えないので、応答の本文（エラーの種類と文）を添える。
// 評価のときだけ使う。本番の道は本文を観測に送らない（応答の本文に記録の中身が入りうるため）
export const describeLlmCallFailure = (
  error: LlmCallError | LlmCallBadRequestError | LlmCallTimedOutError | LlmCallInvalidResponseError,
): string =>
  match(error)
    .with(
      { name: "LlmCallError" },
      { name: "LlmCallBadRequestError" },
      ({ name, errorType, cause }) => {
        const body = responseBodySchema.safeParse(
          cause instanceof APIError ? cause.error : undefined,
        );
        return body.success
          ? `${name}（${body.data.error.type}: ${body.data.error.message}）`
          : `${name}（${errorType}）`;
      },
    )
    .with(
      { name: "LlmCallTimedOutError" },
      { name: "LlmCallInvalidResponseError" },
      ({ name }) => name,
    )
    .exhaustive();

// Anthropic の API のエラーの応答の本文
const responseBodySchema = z.object({
  error: z.object({ type: z.string(), message: z.string() }),
});
