import type Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { catchAnthropicFailure } from "../../src/durable-object/anthropic/catch-anthropic-failure";
import type { LlmCallBadRequestError } from "../../src/domain/llm-call-bad-request-error";
import type { LlmCallError } from "../../src/domain/llm-call-error";
import type { LlmCallTimedOutError } from "../../src/domain/llm-call-timed-out-error";

// 評価の場面を回す前に、同じ鍵で 1 回だけ小さく呼んで確かめる（#565）。
// ワークスペースの月の支出の上限に達していると、場面がばらばらに 400 で落ち、結果が読めなくなるため。
// いちばん安い Haiku 5.5 に、出力 1 トークンで呼ぶ
export const checkEvalKey = (
  client: Anthropic,
): R.ResultAsync<void, LlmCallError | LlmCallBadRequestError | LlmCallTimedOutError> =>
  R.pipe(
    catchAnthropicFailure(
      client.messages.create(
        { model: "claude-haiku-5-5", max_tokens: 1, messages: [{ role: "user", content: "." }] },
        { timeout: 30_000 },
      ),
    ),
    R.map(() => undefined),
  );
