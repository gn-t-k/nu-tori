import { match } from "ts-pattern";
import type { ClassificationEvalOutput } from "../classification-eval-output";

// promptfoo の javascript の assertion。1件の答えが、1つのしきい値で、1種類の間違いになったかを score（1 か 0）で返す。
// assertion に metric を付けて並べると、結果の namedScores にしきい値と種類ごとの件数が出る（promptfooconfig.ts）。
// テストは落とさない（weight 0 で数えるだけ）
export const judgeClassificationError = (
  output: ClassificationEvalOutput,
  context: {
    vars: { expected: "meal" | "chat" };
    config: { threshold: number; error: ClassificationErrorKind };
  },
): { pass: true; score: 0 | 1; reason: string } => {
  const { threshold, error } = context.config;
  const read = readAsMeal(output, threshold) ? "meal" : "chat";
  const wrong = match(error)
    .with("meal_as_chat", () => context.vars.expected === "meal" && read === "chat")
    .with("chat_as_meal", () => context.vars.expected === "chat" && read === "meal")
    .exhaustive();
  return { pass: true, score: wrong ? 1 : 0, reason: `${error}@${threshold}` };
};

// meal_as_chat: 食事を会話にした（記録を落とす）。chat_as_meal: 会話を食事にした（記録を汚す）
export type ClassificationErrorKind = "meal_as_chat" | "chat_as_meal";

// 確からしさはしきい値以上で食事。答えは食事のときだけ食事で、決めかねるは会話にする（#419 の「決めかねたとき」）
const readAsMeal = (output: ClassificationEvalOutput, threshold: number): boolean =>
  match(output)
    .with({ kind: "probability" }, ({ mealProbability }) => mealProbability >= threshold)
    .with({ kind: "label" }, ({ label }) => label === "meal")
    .exhaustive();
