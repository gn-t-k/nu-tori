import type Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { parseJson } from "../../../durable-object/anthropic/parse-json";
import type { ClassificationResult } from "../../domain/conversation-provider";
import { ConversationProviderError } from "../../domain/conversation-provider-error";
import { haikuClassificationOutputSchema } from "./haiku-classification-output-schema";

// Haiku 5.5 の読み分けの応答を読む。評価（server/evals/classify）も同じ読み方で数える。
// 出力の上限で切れた応答と、答えなかった応答は、構造化出力が途中で終わっていたり空だったりする
export const readHaikuClassification = (
  message: Anthropic.Message,
): R.Result<ClassificationResult, ConversationProviderError> => {
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
