import type Anthropic from "@anthropic-ai/sdk";
import { APIConnectionError, APIConnectionTimeoutError, APIError } from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import type { ClassificationReply } from "../../domain/conversation-provider";
import { ConversationProviderError } from "../../domain/conversation-provider-error";
import { createHaikuClassificationRequest } from "./create-haiku-classification-request";
import { haikuClassificationOutputSchema } from "./haiku-classification-output-schema";

// 読み分けの呼び出し1回の時間の上限。アラームは文章を1つずつ読むので、止まった呼び出しが後ろの文章と推定を待たせないよう、
// 短い判断に見合う長さにする（自分で決めた値）
const classificationTimeLimitMs = 30_000;

// Haiku 5.5 に読み分けさせる。失敗はどれも会話になるので、種類（errorType）で分けるだけにし、応答のエラーを cause に持たせる。
// 応答の中身（モデルの答えのテキスト）は残さない
export const classifyWithHaiku = (
  client: Anthropic,
  userId: string,
  body: string,
): R.ResultAsync<ClassificationReply, ConversationProviderError> =>
  client.messages
    .create(
      { ...createHaikuClassificationRequest(body), metadata: { user_id: userId } },
      { timeout: classificationTimeLimitMs },
    )
    .then(readClassification, (error: unknown) => {
      const failure = toProviderFailure(error);
      if (failure === undefined) {
        throw error;
      }
      return R.fail(failure);
    });

// 出力の上限で切れた応答と、答えなかった応答は、構造化出力が途中で終わっていたり空だったりする
const readClassification = (
  message: Anthropic.Message,
): R.Result<ClassificationReply, ConversationProviderError> => {
  if (message.stop_reason === "max_tokens" || message.stop_reason === "refusal") {
    return R.fail(new ConversationProviderError({ errorType: "invalid_response" }));
  }
  const text = message.content.map((block) => (block.type === "text" ? block.text : "")).join("");
  const parsed = haikuClassificationOutputSchema.safeParse(parseJson(text));
  return parsed.success
    ? R.succeed({
        label: parsed.data.label,
        usage: {
          inputTokens: message.usage.input_tokens,
          outputTokens: message.usage.output_tokens,
        },
      })
    : R.fail(new ConversationProviderError({ errorType: "invalid_response" }));
};

// JSON として読めないテキストは、形の確かめで落ちるよう undefined にする
const parseJson = (text: string): unknown => {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
};

// SDK が投げる提供元の失敗。SDK の失敗でないもの（想定外）は undefined を返し、呼び出し側が投げ直す。
// errorType は提供元のエラーの種類（応答に無ければ HTTP の状態コード）。時間切れは timed_out、つなげなかったときは connection_error
const toProviderFailure = (error: unknown): ConversationProviderError | undefined => {
  if (error instanceof APIConnectionTimeoutError) {
    return new ConversationProviderError({ errorType: "timed_out", cause: error });
  }
  if (error instanceof APIConnectionError) {
    return new ConversationProviderError({ errorType: "connection_error", cause: error });
  }
  if (error instanceof APIError) {
    return new ConversationProviderError({
      errorType: error.type ?? `http_${error.status}`,
      cause: error,
    });
  }
  return undefined;
};
