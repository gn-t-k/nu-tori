// モデルがテキストで答えたときの応答（構造化出力の JSON はテキストで返る）
export const replyWithText = (
  text: string,
  options: {
    usage?: { input_tokens: number; output_tokens: number };
    stopReason?: "end_turn" | "max_tokens" | "refusal";
  } = {},
): Response =>
  Response.json({
    id: "msg_test",
    type: "message",
    role: "assistant",
    model: "claude-sonnet-5",
    content: [{ type: "text", text }],
    stop_reason: options.stopReason ?? "end_turn",
    stop_sequence: null,
    usage: options.usage ?? { input_tokens: 1500, output_tokens: 400 },
  });
