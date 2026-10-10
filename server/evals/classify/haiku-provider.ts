import Anthropic from "@anthropic-ai/sdk";
import type { ApiProvider, ProviderResponse } from "promptfoo";
import { createHaikuClassificationRequest } from "../../src/reply/durable-object/create-conversation-provider/create-haiku-classification-request";
import { haikuClassificationOutputSchema } from "../../src/reply/durable-object/create-conversation-provider/haiku-classification-output-schema";
import type { ClassificationEvalOutput } from "./classification-eval-output";

// promptfoo の custom provider。Claude Haiku 5.5 を Anthropic の API で呼ぶ。要求の形はサーバーと同じものを import する。
// 鍵: 開発用のワークスペース（nu-tori-development）のキーを NU_TORI_ANTHROPIC_API_KEY に置く。
// ANTHROPIC_API_KEY はクラウドのセッションでエージェント自身が使う名前なので避ける
export default class HaikuProvider implements ApiProvider {
  id = (): string => "claude-haiku-5-5";

  callApi = async (prompt: string): Promise<ProviderResponse> => {
    const apiKey = process.env["NU_TORI_ANTHROPIC_API_KEY"];
    if (apiKey === undefined) {
      return { error: "開発用のワークスペースのキーを NU_TORI_ANTHROPIC_API_KEY に置いてから回す" };
    }
    // 呼び先を名指す。環境の ANTHROPIC_BASE_URL（エージェントの道具が置くことがある）に向かわないように
    const client = new Anthropic({ apiKey, baseURL: "https://api.anthropic.com" });
    const message = await client.messages.create(createHaikuClassificationRequest(prompt));
    const tokenUsage = {
      prompt: message.usage.input_tokens,
      completion: message.usage.output_tokens,
      total: message.usage.input_tokens + message.usage.output_tokens,
    };
    if (message.stop_reason === "max_tokens" || message.stop_reason === "refusal") {
      return { error: `Haiku 5.5 が答えなかった（${message.stop_reason}）`, tokenUsage };
    }
    const text = message.content.map((block) => (block.type === "text" ? block.text : "")).join("");
    const parsed = haikuClassificationOutputSchema.safeParse(parseJson(text));
    if (!parsed.success) {
      return { error: "Haiku 5.5 の応答を読めなかった", tokenUsage };
    }
    const output: ClassificationEvalOutput = { kind: "label", label: parsed.data.label };
    return { output, tokenUsage };
  };
}

const parseJson = (text: string): unknown => {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
};
