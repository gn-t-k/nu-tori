import { replyEvalCases } from "../cases";
import { readReplyResults } from "../read-reply-results";

// 返事の評価の結果を、PR の本文に貼る形（すべての回で通った場面の数、場面ごとの通った回、落ちた回と理由、プリセットの返事の本文）にする。
// どれかの回で落ちた場面を落ちた場面とし、通った場面の数も同じ判定から数える
// 回し方は evals/run-eval.ts。指示（src/reply/durable-object/create-conversation-provider/reply-instructions.ts）や文脈の文面を変えたら回し直す
export const summarizeReplyResults = (results: unknown): { summary: string; passed: boolean } => {
  const cases = readReplyResults(results);
  const failedCases = cases.filter(({ runs }) => runs.some(({ pass }) => !pass));
  const presetIds = new Set(
    replyEvalCases.filter(({ scene }) => scene === "preset").map(({ id }) => id),
  );
  const summary = [
    `すべての回で通った場面: ${cases.length - failedCases.length} / ${cases.length}`,
    "",
    ...cases.map(
      ({ id, runs }) =>
        `- ${id}: ${runs.filter(({ pass }) => pass).length} / ${runs.length} 回通った`,
    ),
    "",
    ...failedCases.flatMap(({ id, runs }) => [
      `## 落ちた場面: ${id}`,
      "",
      ...runs
        .filter(({ pass }) => !pass)
        .flatMap(({ output, failures }) => [
          ...failures.map(({ rubric, reason }) => `- ${rubric}: ${reason}`),
          "",
          output ?? "（返事なし）",
          "",
        ]),
    ]),
    ...cases
      .filter(({ id }) => presetIds.has(id))
      .flatMap(({ id, runs }) => [
        `## プリセット: ${id}`,
        "",
        runs[0]?.output ?? "（返事なし）",
        "",
      ]),
  ].join("\n");
  return { summary, passed: failedCases.length === 0 };
};
