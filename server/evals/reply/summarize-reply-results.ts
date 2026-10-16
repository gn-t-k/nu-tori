import { replyEvalCases } from "./cases";
import { readReplyResults } from "./read-reply-results";

// 返事の評価の結果を、PR の本文に貼る形（すべての回で通った場面の数、場面ごとの通った回、落ちた回と理由、プリセットの返事の本文）にする。
// 回し方は evals/run-eval.ts。指示（src/reply/durable-object/create-conversation-provider/reply-instructions.ts）や文脈の文面を変えたら回し直す
export const summarizeReplyResults = (results: unknown): { summary: string; passed: boolean } => {
  const { passed, total, cases } = readReplyResults(results);
  const presetIds = new Set(
    replyEvalCases.filter(({ scene }) => scene === "preset").map(({ id }) => id),
  );
  const summary = [
    `すべての回で通った場面: ${passed} / ${total}`,
    "",
    ...cases.map(({ id, passedRuns, runs }) => `- ${id}: ${passedRuns} / ${runs.length} 回通った`),
    "",
    ...cases
      .filter(({ passedRuns, runs }) => passedRuns < runs.length)
      .flatMap(({ id, runs }) => [
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
  return { summary, passed: passed === total };
};
