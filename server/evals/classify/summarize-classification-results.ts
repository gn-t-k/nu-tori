import { readClassificationCases } from "./read-classification-cases";
import { readClassificationResults } from "./read-classification-results";

// 読み分けの評価の結果を、PR の本文に貼る表と、どれかの回で間違えた文章ごとの読めた回にする。
// --repeat で何回か回したときは、表にすべての回の合計を出す。回し方は evals/run-eval.ts
export const summarizeClassificationResults = (
  results: unknown,
): { summary: string; passed: boolean } => {
  const counts = readClassificationResults(results);
  if (counts.status === "incomplete") {
    return {
      summary: [
        `呼び出しに失敗した件がある（${counts.errorCount} 件）。鍵と上限を確かめて回し直す`,
        ...counts.failures.map(({ text, reason }) => `- ${text}: ${reason}`),
      ].join("\n"),
      passed: false,
    };
  }
  const missedCases = readClassificationCases(results).filter(
    ({ passedRuns, runCount }) => passedRuns < runCount,
  );
  return {
    summary: [
      "| モデル | 食事を会話にした | 会話を食事にした |",
      "|---|---|---|",
      `| Claude Haiku 5.5（決めかねるは会話） | ${counts.mealAsChat} | ${counts.chatAsMeal} |`,
      ...(missedCases.length === 0
        ? []
        : [
            "",
            "## 間違えた回のある文章",
            "",
            ...missedCases.map(
              ({ id, passedRuns, runCount }) => `- ${id}: ${passedRuns} / ${runCount} 回読めた`,
            ),
          ]),
    ].join("\n"),
    passed: true,
  };
};
