import Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import type { ApiProvider, ProviderResponse } from "promptfoo";
import { catchAnthropicFailure } from "../../src/durable-object/anthropic/catch-anthropic-failure";
import { createHaikuClassificationRequest } from "../../src/reply/durable-object/create-conversation-provider/create-haiku-classification-request";
import { readHaikuClassification } from "../../src/reply/durable-object/create-conversation-provider/read-haiku-classification";
import { describeLlmCallFailure } from "../describe-llm-call-failure";
import { missingEvalApiKeyMessage, readEvalApiKey } from "../read-eval-api-key";

// promptfoo の custom provider。Claude Haiku 5.5 を Anthropic の API で呼ぶ。要求の形と応答の読み方はサーバーと同じものを import する。
// 鍵の置き場は read-eval-api-key.ts
export default class HaikuProvider implements ApiProvider {
  id = (): string => "claude-haiku-5-5";

  callApi = async (prompt: string): Promise<ProviderResponse> => {
    const apiKey = readEvalApiKey();
    if (apiKey === undefined) {
      return { error: missingEvalApiKeyMessage };
    }
    // 呼び先を名指す。環境の ANTHROPIC_BASE_URL（エージェントの道具が置くことがある）に向かわないように
    const client = new Anthropic({ apiKey, baseURL: "https://api.anthropic.com" });
    const called = await catchAnthropicFailure(
      client.messages.create(createHaikuClassificationRequest(prompt)),
    );
    if (R.isFailure(called)) {
      return { error: `Haiku 5.5 を呼べなかった（${describeLlmCallFailure(called.error)}）` };
    }
    const message = called.value;
    const tokenUsage = {
      prompt: message.usage.input_tokens,
      completion: message.usage.output_tokens,
      total: message.usage.input_tokens + message.usage.output_tokens,
    };
    const classification = readHaikuClassification(message);
    if (R.isFailure(classification)) {
      return { error: "Haiku 5.5 が答えなかったか、応答を読めなかった", tokenUsage };
    }
    return { output: classification.value.label, tokenUsage };
  };
}
