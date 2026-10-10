import type Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import type { z } from "zod";
import { catchAnthropicFailure } from "../../../durable-object/anthropic/catch-anthropic-failure";
import { parseJson } from "../../../durable-object/anthropic/parse-json";
import { EstimationProviderBadRequestError } from "../../domain/estimation-provider-bad-request-error";
import { EstimationProviderError } from "../../domain/estimation-provider-error";
import { EstimationProviderInvalidResponseError } from "../../domain/estimation-provider-invalid-response-error";
import { EstimationProviderTimedOutError } from "../../domain/estimation-provider-timed-out-error";
import type { TokenUsage } from "../../../domain/token-usage";

// 推定の2つの呼び出し（①②）に共通の頼み方。モデルを決め、思考を切り、構造化出力で答えさせ、
// 時間の上限と失敗を提供元の失敗の種類に分ける。応答の中身（モデルの答えのテキスト）は残さず、読めた形と使ったトークンだけを返す
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
  | EstimationProviderError
  | EstimationProviderBadRequestError
  | EstimationProviderTimedOutError
  | EstimationProviderInvalidResponseError
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
      (failure) =>
        match(failure)
          .with(
            { type: "timed_out" },
            ({ cause }) => new EstimationProviderTimedOutError({ cause }),
          )
          .with(
            { type: "bad_request" },
            ({ errorType, cause }) => new EstimationProviderBadRequestError({ errorType, cause }),
          )
          .with(
            { type: "provider_error" },
            ({ errorType, cause }) => new EstimationProviderError({ errorType, cause }),
          )
          .exhaustive(),
    ),
    R.andThen((message) => readStructuredOutput(message, call.schema)),
  );

// 出力の上限で切れた応答と、答えなかった応答は、構造化出力が途中で終わっていたり空だったりする
const readStructuredOutput = <TSchema extends z.ZodType>(
  message: Anthropic.Message,
  schema: TSchema,
): R.Result<
  { output: z.output<TSchema>; usage: TokenUsage },
  EstimationProviderInvalidResponseError
> => {
  const usage = {
    inputTokens: message.usage.input_tokens,
    outputTokens: message.usage.output_tokens,
  };
  if (message.stop_reason === "max_tokens" || message.stop_reason === "refusal") {
    return R.fail(new EstimationProviderInvalidResponseError({ usage }));
  }
  const text = message.content.map((block) => (block.type === "text" ? block.text : "")).join("");
  const parsed = schema.safeParse(parseJson(text));
  return parsed.success
    ? R.succeed({ output: parsed.data, usage })
    : R.fail(new EstimationProviderInvalidResponseError({ usage }));
};
