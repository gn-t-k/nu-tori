import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import type { ApiProvider, ProviderResponse } from "promptfoo";
import { z } from "zod";

// promptfoo の判定役（llm-rubric の grading provider）。返事を作るモデルと別の Claude（Opus 5.5）に、守ることの1項目ずつを判定させる。
// promptfoo が渡すプロンプトは、判定の指示（grading-prompt.ts）を描いたメッセージの並びの JSON。
// 答えは構造化出力で、llm-rubric が読む { reason, pass, score } にする。鍵と呼び先は sonnet-reply-provider.ts と同じ
export default class JudgeProvider implements ApiProvider {
  id = (): string => "claude-opus-5-5";

  callApi = async (prompt: string): Promise<ProviderResponse> => {
    const apiKey = process.env["NU_TORI_ANTHROPIC_API_KEY"];
    if (apiKey === undefined) {
      return { error: "開発用のワークスペースのキーを NU_TORI_ANTHROPIC_API_KEY に置いてから回す" };
    }
    const messages = gradingMessagesSchema.parse(JSON.parse(prompt));
    const client = new Anthropic({ apiKey, baseURL: "https://api.anthropic.com" });
    const message = await client.messages.create({
      model: "claude-opus-5-5",
      max_tokens: 4096,
      system: messages
        .filter(({ role }) => role === "system")
        .map(({ content }) => content)
        .join("\n\n"),
      messages: messages
        .filter(({ role }) => role === "user")
        .map(({ content }) => ({ role: "user" as const, content })),
      output_config: { effort: "medium", format: zodOutputFormat(gradingSchema) },
    });
    const tokenUsage = {
      prompt: message.usage.input_tokens,
      completion: message.usage.output_tokens,
      total: message.usage.input_tokens + message.usage.output_tokens,
    };
    if (message.stop_reason !== "end_turn") {
      return { error: `判定役が答えなかった（${message.stop_reason}）`, tokenUsage };
    }
    const text = message.content.map((block) => (block.type === "text" ? block.text : "")).join("");
    return { output: text, tokenUsage };
  };
}

const gradingMessagesSchema = z.array(
  z.object({ role: z.enum(["system", "user"]), content: z.string() }),
);

const gradingSchema = z.object({
  reason: z.string(),
  pass: z.boolean(),
  score: z.number(),
});
