import Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { computeWrittenMealEatenAt } from "../../src/estimation/domain/compute-written-meal-eaten-at";
import { toWrittenMealsRequest } from "../../src/estimation/domain/to-written-meals-request";
import { identifyWrittenMeals } from "../../src/estimation/durable-object/create-estimation-provider/identify-written-meals";

// 文章の食事の ① が決める食べた時刻の揺れを、本番と同じ指示とモデル（#188 の推定と同じ）で確かめる（#419 の「時刻の決め方」、#434）。
// 目安の時刻は指示に書かず LLM に決めさせているので、同じ文章を何回か読ませ、時刻が回ごとにどれだけ違うかを見る。
// 回し方（手で。CI と scripts/check には入れない）: server/ で `pnpm exec tsx evals/written-meal-times/check-written-meal-times.ts`。
// 鍵は開発用のワークスペースのキー NU_TORI_ANTHROPIC_API_KEY。文章は作り話だけにする（公開リポジトリ）
const runs = 5;

// 送った日時は東京の 2026-10-10（土）。夜食は送った時刻より後に決めると送った時刻に直るので、遅い時刻に送る
const cases = [
  { body: "朝ごはんにトーストとコーヒー", sentAt: "2026-10-10T21:30:00+09:00" },
  { body: "お昼はラーメンでした", sentAt: "2026-10-10T21:30:00+09:00" },
  { body: "夜ごはんは鶏の照り焼きとごはん", sentAt: "2026-10-10T21:30:00+09:00" },
  { body: "遅めの朝ごはんにパンケーキ", sentAt: "2026-10-10T21:30:00+09:00" },
  { body: "おやつにクッキーを3枚", sentAt: "2026-10-10T21:30:00+09:00" },
  { body: "夜食にカップ麺を食べた", sentAt: "2026-10-10T23:50:00+09:00" },
  { body: "朝はパン、昼はうどん", sentAt: "2026-10-10T21:30:00+09:00" },
  { body: "昨日の夜は焼肉", sentAt: "2026-10-10T21:30:00+09:00" },
] as const;

const apiKey = process.env["NU_TORI_ANTHROPIC_API_KEY"];
if (apiKey === undefined) {
  throw new Error("開発用のワークスペースのキーを NU_TORI_ANTHROPIC_API_KEY に置いてから回す");
}
// 呼び先を名指す。環境の ANTHROPIC_BASE_URL（エージェントの道具が置くことがある）に向かわないように
const client = new Anthropic({ apiKey, baseURL: "https://api.anthropic.com" });

const readOnce = async (body: string, sentAt: Date): Promise<string> => {
  const sentText = { body, sentAt, timeZone: "Asia/Tokyo" };
  const identified = await identifyWrittenMeals(
    client,
    "eval",
    toWrittenMealsRequest(sentText),
    AbortSignal.timeout(90_000),
  );
  if (R.isFailure(identified)) {
    return `（失敗: ${identified.error.name}）`;
  }
  return identified.value.output.meals
    .map(({ eatenAt }) => {
      const kept = computeWrittenMealEatenAt(eatenAt, sentText);
      const keptLocal =
        kept === undefined
          ? "読めない"
          : new Date(kept.getTime() + 9 * 60 * 60 * 1000).toISOString().slice(5, 16);
      return keptLocal === eatenAt.slice(5, 16)
        ? eatenAt.slice(5, 16)
        : `${eatenAt.slice(5, 16)}→${keptLocal}`;
    })
    .join(" / ");
};

const rows = await Promise.all(
  cases.map(async ({ body, sentAt }) => {
    const answers: string[] = [];
    for (let run = 0; run < runs; run += 1) {
      answers.push(await readOnce(body, new Date(sentAt)));
    }
    return `| ${body} | ${sentAt.slice(5, 16).replace("T", " ")} | ${answers.join(" | ")} |`;
  }),
);

console.log(
  [
    `| 文章 | 送った日時 | ${Array.from({ length: runs }, (_, run) => `${run + 1}回目`).join(" | ")} |`,
    `|---|---|${"---|".repeat(runs)}`,
    ...rows,
    "",
    "時刻は MM-DDTHH:mm。「→」は範囲の外で送った時刻に直したもの",
  ].join("\n"),
);
