import Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import type { ApiProvider, ProviderResponse } from "promptfoo";
import { createHaikuClassificationRequest } from "../../src/reply/durable-object/create-conversation-provider/create-haiku-classification-request";
import { readHaikuClassification } from "../../src/reply/durable-object/create-conversation-provider/read-haiku-classification";
import type { ClassificationEvalOutput } from "./classification-eval-output";

// promptfoo の custom provider。Claude Haiku 5.5 を Anthropic の API で呼ぶ。要求の形と応答の読み方はサーバーと同じものを import する。
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
    const classification = readHaikuClassification(message);
    if (R.isFailure(classification)) {
      return { error: "Haiku 5.5 が答えなかったか、応答を読めなかった", tokenUsage };
    }
    const output: ClassificationEvalOutput = { kind: "label", label: classification.value.label };
    return { output, tokenUsage };
  };
}
