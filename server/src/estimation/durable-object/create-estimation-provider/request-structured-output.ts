import type Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { R } from "@praha/byethrow";
import type { z } from "zod";
import { catchAnthropicFailure } from "../../../durable-object/anthropic/catch-anthropic-failure";
import { parseJson } from "../../../durable-object/anthropic/parse-json";
import type { LlmCallBadRequestError } from "../../../domain/llm-call-bad-request-error";
import type { LlmCallError } from "../../../domain/llm-call-error";
import { LlmCallInvalidResponseError } from "../../../domain/llm-call-invalid-response-error";
import type { LlmCallTimedOutError } from "../../../domain/llm-call-timed-out-error";
import type { TokenUsage } from "../../../domain/token-usage";

// 推定の2つの呼び出し（①②）に共通の頼み方。モデルを決め、思考を切り、構造化出力で答えさせ、
// 時間の上限をかける。提供元の失敗は catchAnthropicFailure が LLM の呼び出しの失敗に写す。応答の中身（モデルの答えのテキスト）は残さず、読めた形と使ったトークンだけを返す
export const requestStructuredOutput = <TSchema extends z.ZodType>(
  client: Anthropic,
  call: {
    system: string;
    content: Anthropic.ContentBlockParam[];
    schema: TSchema;
    // 提供元に渡す、アカウント ID を元に戻せない形に変えた値
    userId: string;
    // この呼び出し1回の時間の上限（ミリ秒）。試み全体の上限は signal で渡る
    timeLimitMs: number;
  },
  signal: AbortSignal,
): R.ResultAsync<
  { output: z.output<TSchema>; usage: TokenUsage },
  LlmCallError | LlmCallBadRequestError | LlmCallTimedOutError | LlmCallInvalidResponseError
> =>
  R.pipe(
    catchAnthropicFailure(
      client.messages.create(
        {
          // 仕様（#188）の指定。差し替えるときはここだけを直す
          model: "claude-sonnet-5",
          max_tokens: 8192,
          // 思考は明示して切る（Sonnet 5 は省くと適応的な思考が動く）
          thinking: { type: "disabled" },
          metadata: { user_id: call.userId },
          system: call.system,
          messages: [{ role: "user", content: call.content }],
          output_config: { format: zodOutputFormat(call.schema) },
        },
        { signal, timeout: call.timeLimitMs },
      ),
    ),
    R.andThen((message) => readStructuredOutput(message, call.schema)),
  );

// 出力の上限で切れた応答と、答えなかった応答は、構造化出力が途中で終わっていたり空だったりする
const readStructuredOutput = <TSchema extends z.ZodType>(
  message: Anthropic.Message,
  schema: TSchema,
): R.Result<{ output: z.output<TSchema>; usage: TokenUsage }, LlmCallInvalidResponseError> => {
  const usage: TokenUsage = {
    type: "uncached",
    inputTokens: message.usage.input_tokens,
    outputTokens: message.usage.output_tokens,
  };
  if (message.stop_reason === "max_tokens" || message.stop_reason === "refusal") {
    return R.fail(new LlmCallInvalidResponseError({ usage }));
  }
  const text = message.content.map((block) => (block.type === "text" ? block.text : "")).join("");
  const parsed = schema.safeParse(parseJson(text));
  return parsed.success
    ? R.succeed({ output: parsed.data, usage })
    : R.fail(new LlmCallInvalidResponseError({ usage }));
};
