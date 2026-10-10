import type Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { classificationCriteria } from "./classification-criteria";
import { haikuClassificationOutputSchema } from "./haiku-classification-output-schema";

// Claude Haiku 5.5 で読み分けるときの要求。確信度を返さないので、答えを meal・conversation・unsure の3つにし、
// unsure は会話として扱う（#419 の「読み分け」）。答えは構造化出力の label を haikuClassificationOutputSchema で読む
export const createHaikuClassificationRequest = (
  body: string,
): Anthropic.MessageCreateParamsNonStreaming => ({
  model: "claude-haiku-5-5",
  max_tokens: 256,
  // 読み分けは短い判断なので思考を切る（Haiku 5.5 は effort が high 以下なら切れる）
  thinking: { type: "disabled" },
  system: haikuClassificationSystem,
  messages: [{ role: "user", content: body }],
  output_config: { effort: "low", format: zodOutputFormat(haikuClassificationOutputSchema) },
});

const haikuClassificationSystem = [
  "あなたは食事の記録アプリで、利用者が書いて送った文章を読み分けます。利用者の文章はユーザーのメッセージ1つで届きます。",
  "",
  `- meal: ${classificationCriteria.meal}`,
  `- conversation: ${classificationCriteria.conversation}`,
  "- unsure: meal と conversation のどちらとも決めきれない",
  "",
  "meal にした文章は食事として記録され、conversation と unsure にした文章には AI が返事をします。label に1つを答えてください。",
].join("\n");
