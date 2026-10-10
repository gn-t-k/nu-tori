import { readFile } from "node:fs/promises";
import { readClassificationResults } from "./read-classification-results";

// 読み分けの評価の結果を、PR の本文に貼る表にして出す。
// 回し方（手で。CI と scripts/check には入れない）: server/ で `pnpm run evals:classify`。
// 鍵は開発用のワークスペースのキー NU_TORI_ANTHROPIC_API_KEY だけを使う。
// 結果の JSON は .scratch/（gitignore）に書く
const resultsPath = process.argv[2];
if (resultsPath === undefined) {
  throw new Error("使い方: tsx evals/classify/summarize-classification-results.ts <results.json>");
}
const results = readClassificationResults(JSON.parse(await readFile(resultsPath, "utf8")));

if (results.status === "incomplete") {
  console.error(
    `呼び出しに失敗した件がある（${results.errorCount} 件）。鍵と上限を確かめて回し直す`,
  );
  process.exitCode = 1;
} else {
  console.log(
    [
      "| モデル | 食事を会話にした | 会話を食事にした |",
      "|---|---|---|",
      `| Claude Haiku 5.5（決めかねるは会話） | ${results.mealAsChat} | ${results.chatAsMeal} |`,
    ].join("\n"),
  );
}
