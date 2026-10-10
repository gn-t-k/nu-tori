import { match } from "ts-pattern";
import type { ClassificationLabel } from "../../../src/reply/domain/conversation-provider";

// promptfoo の javascript の assertion。1件の答えが、1種類の間違いになったかを score（1 か 0）で返す。
// assertion に metric を付けて並べると、結果の namedScores に種類ごとの件数が出る（promptfooconfig.ts）。
// テストは落とさない（weight 0 で数えるだけ）
export const judgeClassificationError = (
  output: ClassificationLabel,
  context: {
    vars: { expected: "meal" | "chat" };
    config: { error: ClassificationErrorKind };
  },
): { pass: true; score: 0 | 1; reason: string } => {
  const { error } = context.config;
  // 決めかねるは会話にする（#419 の「決めかねたとき」）
  const read = output === "meal" ? "meal" : "chat";
  const wrong = match(error)
    .with("meal_as_chat", () => context.vars.expected === "meal" && read === "chat")
    .with("chat_as_meal", () => context.vars.expected === "chat" && read === "meal")
    .exhaustive();
  return { pass: true, score: wrong ? 1 : 0, reason: error };
};

// meal_as_chat: 食事を会話にした（記録を落とす）。chat_as_meal: 会話を食事にした（記録を汚す）
export type ClassificationErrorKind = "meal_as_chat" | "chat_as_meal";
