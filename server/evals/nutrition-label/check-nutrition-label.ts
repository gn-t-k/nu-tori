import { execFileSync } from "node:child_process";
import { mkdir, readdir, readFile } from "node:fs/promises";
import path from "node:path";
import Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { z } from "zod";
import { identifyDishes } from "../../src/estimation/durable-object/create-estimation-provider/identify-dishes";
import { describeLlmCallFailure } from "../describe-llm-call-failure";
import { missingEvalApiKeyMessage, readEvalApiKey } from "../read-eval-api-key";
import { serverDirectory } from "../server-directory";
import { judgeNutritionLabelRun, type RunVerdict } from "./judge-nutrition-label-run";
import { nutritionLabelCaseSchema, toIdentificationTarget } from "./nutrition-label-case";

// 栄養成分表示の読み取り（#1036）を、本番と同じ ① の指示とモデルで、ケースごとに5回呼んで確かめる（#1037）。② は呼ばない。
// 答えは本番の推定の試みと同じ検証と、栄養の合計の数え方を通してから正解と比べる（judge-nutrition-label-run）。
// 回し方（手で。CI と scripts/check には入れない）: server/ で `pnpm exec tsx evals/nutrition-label/check-nutrition-label.ts`。
// 鍵の置き場は read-eval-api-key.ts。ケース（写真と expected.json）は R2 の nu-tori-evals の nutrition-label/ から、gitignore した .scratch/nutrition-label/ に落として読む（パッケージの写真を公開リポジトリに入れない）。R2 の鍵が無ければ、そこに手で置いたケースだけを回す。
// 正解の形は nutrition-label-case.ts
const runs = 5;

const prefix = "nutrition-label/";
const casesDirectory = path.join(serverDirectory, ".scratch", "nutrition-label");

const downloadCases = async (): Promise<void> => {
  const cloudflare = path.join(serverDirectory, "..", "scripts", "cloudflare");
  const keys = z
    .array(z.object({ key: z.string() }))
    .parse(JSON.parse(execFileSync(cloudflare, ["evals", "list", prefix], { encoding: "utf8" })))
    .map(({ key }) => key)
    // R2 の画面で作ったフォルダの印（末尾が /）は落とさない
    .filter((key) => !key.endsWith("/"));
  for (const key of keys) {
    const destination = path.join(casesDirectory, key.slice(prefix.length));
    await mkdir(path.dirname(destination), { recursive: true });
    execFileSync(cloudflare, ["evals", "get", key, destination]);
  }
  console.log(`R2 から ${keys.length} 個のファイルを落とした`);
};

const apiKey = readEvalApiKey();
if (apiKey === undefined) {
  throw new Error(missingEvalApiKeyMessage);
}
// 呼び先を名指す。環境の ANTHROPIC_BASE_URL（エージェントの道具が置くことがある）に向かわないように
const client = new Anthropic({ apiKey, baseURL: "https://api.anthropic.com" });

await mkdir(casesDirectory, { recursive: true });
try {
  await downloadCases();
} catch (error) {
  console.warn(`R2 から落とせなかったので、手元のケースだけを回す: ${String(error)}`);
}

const readArrayBuffer = async (file: string): Promise<ArrayBuffer> => {
  const read = await readFile(file);
  return read.buffer.slice(read.byteOffset, read.byteOffset + read.byteLength);
};

const caseNames = (await readdir(casesDirectory, { withFileTypes: true }))
  .filter((entry) => entry.isDirectory())
  .map(({ name }) => name)
  .toSorted();
if (caseNames.length === 0) {
  throw new Error(`ケースが無い（${casesDirectory}）`);
}

const judgedCases = await Promise.all(
  caseNames.map(async (name) => {
    const directory = path.join(casesDirectory, name);
    const nutritionLabelCase = nutritionLabelCaseSchema.parse(
      JSON.parse(await readFile(path.join(directory, "expected.json"), "utf8")),
    );
    const photoFiles = (await readdir(directory))
      .filter((file) => /^photo-\d+\.jpe?g$/i.test(file))
      .toSorted();
    const photos = await Promise.all(
      photoFiles.map((file) => readArrayBuffer(path.join(directory, file))),
    );
    const verdicts: RunVerdict[] = [];
    for (let run = 0; run < runs; run += 1) {
      const identified = await identifyDishes(
        client,
        "eval",
        { photos, target: toIdentificationTarget(nutritionLabelCase.target) },
        AbortSignal.timeout(90_000),
      );
      verdicts.push(
        R.isFailure(identified)
          ? {
              type: "failed",
              reason: `呼び出しの失敗: ${describeLlmCallFailure(identified.error)}`,
            }
          : judgeNutritionLabelRun(identified.value.output, nutritionLabelCase),
      );
    }
    return { name, photoCount: photos.length, verdicts };
  }),
);

const rows = judgedCases.map(({ name, photoCount, verdicts }) => {
  const passedCount = verdicts.filter(({ type }) => type === "passed").length;
  const cells = verdicts.map((verdict) => (verdict.type === "passed" ? "○" : "✕"));
  return `| ${name}（写真 ${photoCount} 枚） | ${cells.join(" | ")} | ${passedCount}/${runs} |`;
});

const reasons = judgedCases.flatMap(({ name, verdicts }) =>
  verdicts.flatMap((verdict, run) =>
    verdict.type === "failed" ? [`- ${name} ${run + 1}回目: ${verdict.reason}`] : [],
  ),
);

const totalPassed = judgedCases
  .flatMap(({ verdicts }) => verdicts)
  .filter(({ type }) => type === "passed").length;

console.log(
  [
    `| ケース | ${Array.from({ length: runs }, (_, run) => `${run + 1}回目`).join(" | ")} | 合格 |`,
    `|---|${"---|".repeat(runs)}---|`,
    ...rows,
    "",
    ...reasons,
    "",
    `合格 ${totalPassed}/${judgedCases.length * runs}。合格は、本番の検証に通り、料理の数と名前、表示と成分表の材料の数が正解と合い、表示の材料の栄養が表示と一致した回（許す差は kcal・P・F・C が ±1、食塩相当量が ±0.1。表示が写っていないケースは、表示の材料が1つも無い回）`,
  ].join("\n"),
);
