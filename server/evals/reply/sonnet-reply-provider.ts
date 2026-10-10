import Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import type { ApiProvider, ProviderResponse } from "promptfoo";
import { replyAttemptTimeLimitMs } from "../../src/reply/domain/reply-attempt-time-limit-ms";
import { createAnthropicConversationProvider } from "../../src/reply/durable-object/create-conversation-provider/create-anthropic-conversation-provider";
import { replyEvalCases } from "./cases";

// promptfoo の custom provider。場面の文脈で、本番と同じ道（指示・要求・流した本文の読み取り）を通して Claude Sonnet 5.5 に返事を作らせる。
// プロンプトは場面の名前だけで、文脈は cases.ts から引く。本文を output に、指し示す食事を metadata.mealIds に返す。
// 鍵: 開発用のワークスペース（nu-tori-development）のキーを NU_TORI_ANTHROPIC_API_KEY に置く。
// ANTHROPIC_API_KEY はクラウドのセッションでエージェント自身が使う名前なので避ける
export default class SonnetReplyProvider implements ApiProvider {
  id = (): string => "claude-sonnet-5-5";

  callApi = async (prompt: string): Promise<ProviderResponse> => {
    const apiKey = process.env["NU_TORI_ANTHROPIC_API_KEY"];
    if (apiKey === undefined) {
      return { error: "開発用のワークスペースのキーを NU_TORI_ANTHROPIC_API_KEY に置いてから回す" };
    }
    const evalCase = replyEvalCases.find(({ id }) => id === prompt);
    if (evalCase === undefined) {
      return { error: `場面 ${prompt} が評価の組に無い` };
    }
    // 呼び先を名指す。環境の ANTHROPIC_BASE_URL（エージェントの道具が置くことがある）に向かわないように。
    // 再試行は本番と同じく SDK でしない（落ちたら回し直す）
    const client = new Anthropic({ apiKey, baseURL: "https://api.anthropic.com", maxRetries: 0 });
    const generated = await createAnthropicConversationProvider(client, "eval").generateReply(
      { context: evalCase.context, onText: () => {} },
      AbortSignal.timeout(replyAttemptTimeLimitMs),
    );
    if (R.isFailure(generated)) {
      return { error: `返事を作れなかった（${generated.error.name}）` };
    }
    const { body, mealIds, usage } = generated.value;
    return {
      output: body,
      metadata: { mealIds },
      tokenUsage: {
        prompt: usage.inputTokens,
        completion: usage.outputTokens,
        total: usage.inputTokens + usage.outputTokens,
      },
    };
  };
}
