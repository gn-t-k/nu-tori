import { readFile } from "node:fs/promises";
import { classificationThresholds } from "./classification-thresholds";
import { decideClassificationModel } from "./decide-classification-model";
import { readClassificationResults } from "./read-classification-results";

// 読み分けのモデルの比べ方の結果を、PR の本文に貼る表と決めたものにして出す。
// 回し方（手で。CI と scripts/check には入れない）: server/ で `pnpm run evals:classify`。
// 鍵は開発用だけを使う。Jev は NU_TORI_CLOUDFLARE_ACCOUNT_ID と NU_TORI_CLOUDFLARE_AI_TOKEN（Workers AI の Read）、
// Haiku 5.5 は開発用のワークスペースの ANTHROPIC_API_KEY。結果の JSON は .scratch/（gitignore）に書く
const resultsPath = process.argv[2];
if (resultsPath === undefined) {
  throw new Error("使い方: tsx evals/classify/summarize-classification-results.ts <results.json>");
}
const results = readClassificationResults(JSON.parse(await readFile(resultsPath, "utf8")));

if (results.status === "incomplete") {
  console.error(
    `呼び出しに失敗した件がある（Jev ${results.errorCounts.jev} 件、Haiku 5.5 ${results.errorCounts.haiku} 件）。鍵と上限を確かめて回し直す`,
  );
  process.exitCode = 1;
} else {
  const decision = decideClassificationModel(results);
  console.log(
    [
      "| モデル | しきい値 | 食事を会話にした | 会話を食事にした |",
      "|---|---|---|---|",
      ...results.jev.map(
        ({ threshold, mealAsChat, chatAsMeal }) =>
          `| Jev | ${threshold.toFixed(2)} | ${mealAsChat} | ${chatAsMeal} |`,
      ),
      `| Claude Haiku 5.5 | （決めかねるは会話） | ${results.haiku.mealAsChat} | ${results.haiku.chatAsMeal} |`,
      "",
      decision.model === "jev"
        ? `決めたもの: Jev、しきい値 ${decision.threshold.toFixed(2)}`
        : `決めたもの: Claude Haiku 5.5（Jev は ${classificationThresholds[0]}〜${classificationThresholds.at(-1)} のどのしきい値でも条件を満たさない）`,
    ].join("\n"),
  );
}
