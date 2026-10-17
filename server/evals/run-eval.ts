import { mkdir } from "node:fs/promises";
import path from "node:path";
import { describeCommit } from "./describe-commit";
import { evalSuites } from "./eval-suites";
import { exitIfEvalKeyFails } from "./exit-if-eval-key-fails";
import { parseEvalArguments } from "./parse-eval-arguments";
import { runPromptfoo } from "./run-promptfoo";
import { serverDirectory } from "./server-directory";

// LLM の評価を回し、PR の本文に貼る要約を出す（読み分けは classify、返事は reply）。
// 回し方（手で。CI と scripts/check には入れない）: server/ で `pnpm run evals:reply`（`--repeat 3` で場面ごとに 3 回回し、通った回を数える）。
// 鍵は開発用のワークスペースのキー NU_TORI_ANTHROPIC_API_KEY。場面を回す前に鍵で呼べるかを確かめる。
// 結果の JSON は .scratch/（gitignore）に書く。別の版と比べるときは compare-eval.ts
const { suiteName, rest, repeat } = parseEvalArguments(
  process.argv.slice(2),
  "tsx evals/run-eval.ts <classify|reply> [--repeat N]",
);
if (rest.length > 0) {
  throw new Error(`知らない引数: ${rest.join(" ")}`);
}
const suite = evalSuites[suiteName];

await exitIfEvalKeyFails();
const scratchDirectory = path.join(serverDirectory, ".scratch");
await mkdir(scratchDirectory, { recursive: true });
const results = await runPromptfoo({
  directory: serverDirectory,
  configPath: suite.configPath,
  repeat,
  outputPath: path.join(scratchDirectory, `${suiteName}-results.json`),
});
const { summary, passed } = suite.summarize(results);
console.log(
  [
    `評価したコミット: ${describeCommit(serverDirectory)}`,
    `場面ごとに回した数: ${repeat}`,
    "",
    summary,
  ].join("\n"),
);
if (!passed) {
  process.exitCode = 1;
}
