import { readFile } from "node:fs/promises";
import { replyEvalCases } from "./cases";
import { readReplyResults } from "./read-reply-results";

// 返事の評価の結果を、PR の本文に貼る形（通った数、落ちた場面と理由、プリセットの返事の本文）にして出す。
// 回し方（手で。CI と scripts/check には入れない）: server/ で `pnpm run evals:reply`。
// 鍵は開発用のワークスペースのキー NU_TORI_ANTHROPIC_API_KEY（返事の Sonnet 5.5 と判定役の Opus 5.5）。結果の JSON は .scratch/（gitignore）に書く。
// 指示（src/reply/durable-object/create-conversation-provider/reply-instructions.ts）や文脈の文面を変えたら回し直す
const resultsPath = process.argv[2];
if (resultsPath === undefined) {
  throw new Error("使い方: tsx evals/reply/summarize-reply-results.ts <results.json>");
}
const { passed, total, cases } = readReplyResults(JSON.parse(await readFile(resultsPath, "utf8")));

const presetIds = new Set(
  replyEvalCases.filter(({ scene }) => scene === "preset").map(({ id }) => id),
);
console.log(
  [
    `通った場面: ${passed} / ${total}`,
    "",
    ...cases
      .filter(({ pass }) => !pass)
      .flatMap(({ id, output, failures }) => [
        `## 落ちた場面: ${id}`,
        ...failures.map(({ rubric, reason }) => `- ${rubric}: ${reason}`),
        "",
        output ?? "（返事なし）",
        "",
      ]),
    ...cases
      .filter(({ id }) => presetIds.has(id))
      .flatMap(({ id, output }) => [`## プリセット: ${id}`, "", output ?? "（返事なし）", ""]),
  ].join("\n"),
);
if (passed < total) {
  process.exitCode = 1;
}
