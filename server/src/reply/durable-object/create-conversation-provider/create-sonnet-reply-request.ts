import type Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import type { ReplyContext } from "../../domain/reply-context";
import { renderReplyContext } from "../../domain/render-reply-context";
import { replyInstructions } from "./reply-instructions";
import { sonnetReplyOutputSchema } from "./sonnet-reply-output-schema";

// Claude Sonnet 5.5 に返事を作らせるときの要求（#419 の「返事を作る」）。並びは、変わらない指示（system）→ 文脈の窓 → 構造化した値 → 新しい発言。
// 窓の塊のあとにキャッシュの印を付け、指示と窓をキャッシュから読ませる（窓は末尾にだけ足していくので、次の返事でも前が同じになる）。
// 答えは構造化出力の { body, mealIds } を sonnetReplyOutputSchema で読む。評価の道具（#434）も、この要求をそのまま送る
export const createSonnetReplyRequest = (
  context: ReplyContext,
): Anthropic.MessageCreateParamsStreaming => ({
  model: "claude-sonnet-5-5",
  max_tokens: 4096,
  // 思考は明示して切る。Sonnet 5.5 は disabled を受け付けず、between_tools が一番低い（effort が high 以下のときだけ）
  thinking: { type: "between_tools" },
  system: replyInstructions,
  messages: [
    {
      role: "user",
      content: renderReplyContext(context).map(({ kind, text }) =>
        kind === "window"
          ? { type: "text", text, cache_control: { type: "ephemeral" } }
          : { type: "text", text },
      ),
    },
  ],
  // 会話の返事なので effort は低くする（自分で決めた値。#434 の評価で見直す）
  output_config: { effort: "low", format: zodOutputFormat(sonnetReplyOutputSchema) },
  stream: true,
});
