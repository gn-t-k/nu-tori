import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { toWrittenMealsRequest } from "../../src/estimation/domain/to-written-meals-request";
import type { IdentifiedIngredient } from "../../src/estimation/domain/estimation-provider";
import { identifyDishes } from "../../src/estimation/durable-object/create-estimation-provider/identify-dishes";
import { identifyWrittenMeals } from "../../src/estimation/durable-object/create-estimation-provider/identify-written-meals";

// ① が答える材料の g（食べた分の可食部の g）が、ありうる範囲に収まるかを、本番と同じ指示とモデルで確かめる（#517）。
// 量と1単位あたりの g を別々に答えさせていたとき、重ねて答えて桁が跳ねた（卵 50 g × 50 = 2,500 g）。
// 同じ食事を何回か読ませ、材料ごとの g と、範囲から外れた数、桁が違う数を出す。
// 回し方（手で。CI と scripts/check には入れない）: server/ で `pnpm exec tsx evals/ingredient-grams/check-ingredient-grams.ts`。
// 鍵は開発用のワークスペースのキー NU_TORI_ANTHROPIC_API_KEY。文章は作り話だけにする（公開リポジトリ）。
// 手元の写真も読ませるときは、JPEG を .scratch/ingredient-grams/（gitignore）に置く。範囲は持たないので、桁だけを見る
const runs = 5;

// 範囲の外でも、上限の 3 倍までと下限の 3 分の 1 までは見積もりの揺れとみなし、それより外を桁が違うと数える
const wildFactor = 3;

// 範囲を持たない材料（調味料や、手元の写真の材料）で、桁が違うとみなす g
const wildGramsWithoutRange = 1000;

type ExpectedIngredient = {
  label: string;
  // 材料の名前にどれかが入っていれば、この材料とみなす
  keywords: readonly string[];
  minGrams: number;
  maxGrams: number;
};

const egg = (count: number): ExpectedIngredient => ({
  label: `卵 ${count} 個`,
  keywords: ["卵", "たまご", "玉子"],
  minGrams: 40 * count,
  maxGrams: 70 * count,
});

const rice: ExpectedIngredient = {
  label: "ご飯 1 杯",
  keywords: ["飯", "ごはん", "ライス", "米"],
  minGrams: 100,
  maxGrams: 300,
};

const writtenCases: readonly { body: string; expected: readonly ExpectedIngredient[] }[] = [
  {
    body: "朝は麦ご飯1杯と納豆1パックと生卵1個",
    expected: [
      egg(1),
      rice,
      { label: "納豆 1 パック", keywords: ["納豆"], minGrams: 30, maxGrams: 55 },
    ],
  },
  { body: "卵かけご飯を食べた", expected: [egg(1), rice] },
  { body: "ゆで卵を2個", expected: [egg(2)] },
  {
    body: "牛乳をコップ1杯飲んだ",
    expected: [{ label: "牛乳 1 杯", keywords: ["牛乳", "ミルク"], minGrams: 150, maxGrams: 270 }],
  },
  {
    body: "バナナ1本",
    expected: [{ label: "バナナ 1 本", keywords: ["バナナ"], minGrams: 70, maxGrams: 150 }],
  },
  {
    body: "食パン1枚にバターを塗って食べた",
    expected: [
      { label: "食パン 1 枚", keywords: ["パン"], minGrams: 40, maxGrams: 100 },
      { label: "バター", keywords: ["バター"], minGrams: 3, maxGrams: 20 },
    ],
  },
  {
    body: "鶏むね肉200gを焼いて食べた",
    expected: [{ label: "鶏むね肉 200 g", keywords: ["鶏", "とり"], minGrams: 130, maxGrams: 220 }],
  },
  {
    body: "サラダにオリーブオイルを大さじ1かけた",
    expected: [
      {
        label: "オリーブオイル 大さじ 1",
        keywords: ["オリーブ", "油", "オイル"],
        minGrams: 9,
        maxGrams: 16,
      },
    ],
  },
  {
    body: "緑茶のペットボトル500mlを1本",
    expected: [{ label: "緑茶 500 ml", keywords: ["茶"], minGrams: 450, maxGrams: 550 }],
  },
];

const committedPhotoCases: readonly { file: string; expected: readonly ExpectedIngredient[] }[] = [
  {
    file: path.join(import.meta.dirname, "../../e2e/photos/oyakodon.jpg"),
    expected: [
      { label: "卵", keywords: ["卵", "たまご", "玉子"], minGrams: 40, maxGrams: 140 },
      { label: "ご飯", keywords: rice.keywords, minGrams: 120, maxGrams: 350 },
      { label: "鶏肉", keywords: ["鶏", "とり"], minGrams: 40, maxGrams: 180 },
    ],
  },
];

const localPhotoDirectory = path.join(import.meta.dirname, "../../.scratch/ingredient-grams");

const apiKey = process.env["NU_TORI_ANTHROPIC_API_KEY"];
if (apiKey === undefined) {
  throw new Error("開発用のワークスペースのキーを NU_TORI_ANTHROPIC_API_KEY に置いてから回す");
}
// 呼び先を名指す。環境の ANTHROPIC_BASE_URL（エージェントの道具が置くことがある）に向かわないように
const client = new Anthropic({ apiKey, baseURL: "https://api.anthropic.com" });

type ReadIngredients = readonly IdentifiedIngredient[] | undefined;

const readWrittenOnce = async (body: string): Promise<ReadIngredients> => {
  const identified = await identifyWrittenMeals(
    client,
    "eval",
    toWrittenMealsRequest({
      body,
      // 東京の 2026-10-10（土）21:30
      sentAt: new Date("2026-10-10T21:30:00+09:00"),
      timeZone: "Asia/Tokyo",
    }),
    AbortSignal.timeout(90_000),
  );
  return R.isFailure(identified)
    ? undefined
    : identified.value.output.meals.flatMap(({ dishes }) =>
        dishes.flatMap(({ ingredients }) => ingredients),
      );
};

const readPhotoOnce = async (photo: ArrayBuffer): Promise<ReadIngredients> => {
  const identified = await identifyDishes(
    client,
    "eval",
    { photos: [photo], target: { type: "meal" } },
    AbortSignal.timeout(90_000),
  );
  return R.isFailure(identified)
    ? undefined
    : identified.value.output.dishes.flatMap(({ ingredients }) => ingredients);
};

const readRuns = async (readOnce: () => Promise<ReadIngredients>): Promise<ReadIngredients[]> => {
  const answers: ReadIngredients[] = [];
  for (let run = 0; run < runs; run += 1) {
    answers.push(await readOnce());
  }
  return answers;
};

const readPhoto = async (file: string): Promise<ArrayBuffer> => {
  const photo = await readFile(file);
  return photo.buffer.slice(photo.byteOffset, photo.byteOffset + photo.byteLength);
};

type Verdict = "in_range" | "out_of_range" | "wild";

const judge = (grams: number, expected: ExpectedIngredient | undefined): Verdict => {
  if (expected === undefined) {
    return grams > wildGramsWithoutRange ? "wild" : "in_range";
  }
  if (grams >= expected.minGrams && grams <= expected.maxGrams) {
    return "in_range";
  }
  return grams > expected.maxGrams * wildFactor || grams < expected.minGrams / wildFactor
    ? "wild"
    : "out_of_range";
};

const marks: Readonly<Record<Verdict, string>> = { in_range: "", out_of_range: " △", wild: " ✕" };

const counts: Record<Verdict, number> = { in_range: 0, out_of_range: 0, wild: 0 };

let failedReadCount = 0;

const formatGrams = (grams: number): string => String(Math.round(grams * 10) / 10);

// 範囲を持つ材料は、材料ごとに1行で、回ごとの g を並べる。同じ回に当てはまる材料がいくつもあれば足す
const toExpectedRows = (
  title: string,
  expected: readonly ExpectedIngredient[],
  answers: readonly ReadIngredients[],
): string[] =>
  expected.map((ingredient) => {
    const cells = answers.map((answer) => {
      if (answer === undefined) {
        return "失敗";
      }
      const matched = answer.filter(({ name }) =>
        ingredient.keywords.some((keyword) => name.includes(keyword)),
      );
      if (matched.length === 0) {
        return "無い";
      }
      const grams = matched.reduce((sum, { edibleGrams }) => sum + edibleGrams, 0);
      const verdict = judge(grams, ingredient);
      counts[verdict] += 1;
      return `${formatGrams(grams)}${marks[verdict]}`;
    });
    return `| ${title} | ${ingredient.label} | ${ingredient.minGrams}〜${ingredient.maxGrams} | ${cells.join(" | ")} |`;
  });

// 範囲を持たない材料は、回ごとに、桁が違うものだけを名前つきで挙げる
const toUnexpectedWildLines = (
  title: string,
  expected: readonly ExpectedIngredient[],
  answers: readonly ReadIngredients[],
): string[] =>
  answers.flatMap((answer, run) =>
    (answer ?? [])
      .filter(
        ({ name }) =>
          !expected.some(({ keywords }) => keywords.some((keyword) => name.includes(keyword))),
      )
      .filter(({ edibleGrams }) => judge(edibleGrams, undefined) === "wild")
      .map(({ name, quantity, unit, edibleGrams }) => {
        counts.wild += 1;
        return `- ${title} ${run + 1}回目: ${name} ${quantity} ${unit} = ${formatGrams(edibleGrams)} g ✕`;
      }),
  );

const localPhotoFiles = await readdir(localPhotoDirectory)
  .then((names) => names.filter((name) => /\.jpe?g$/i.test(name)).toSorted())
  .catch(() => []);

const results = await Promise.all([
  ...writtenCases.map(async ({ body, expected }) => ({
    title: body,
    expected,
    answers: await readRuns(() => readWrittenOnce(body)),
  })),
  ...committedPhotoCases.map(async ({ file, expected }) => {
    const photo = await readPhoto(file);
    return {
      title: `写真 ${path.basename(file)}`,
      expected,
      answers: await readRuns(() => readPhotoOnce(photo)),
    };
  }),
  ...localPhotoFiles.map(async (name) => {
    const photo = await readPhoto(path.join(localPhotoDirectory, name));
    return {
      title: `手元の写真 ${name}`,
      expected: [],
      answers: await readRuns(() => readPhotoOnce(photo)),
    };
  }),
]);

const rows = results.flatMap(({ title, expected, answers }) => {
  failedReadCount += answers.filter((answer) => answer === undefined).length;
  return toExpectedRows(title, expected, answers);
});
const wildLines = results.flatMap(({ title, expected, answers }) =>
  toUnexpectedWildLines(title, expected, answers),
);
// 手元の写真は範囲を持たないので、読んだ材料をそのまま並べる
const localLines = results
  .filter(({ title }) => title.startsWith("手元の写真"))
  .flatMap(({ title, answers }) =>
    answers.map(
      (answer, run) =>
        `- ${title} ${run + 1}回目: ${
          answer === undefined
            ? "失敗"
            : answer
                .map(
                  ({ name, quantity, unit, edibleGrams }) =>
                    `${name} ${quantity} ${unit} = ${formatGrams(edibleGrams)} g`,
                )
                .join("、")
        }`,
    ),
  );

console.log(
  [
    `| 食事 | 材料 | ありうる g | ${Array.from({ length: runs }, (_, run) => `${run + 1}回目`).join(" | ")} |`,
    `|---|---|---|${"---|".repeat(runs)}`,
    ...rows,
    "",
    ...localLines,
    ...wildLines,
    "",
    `範囲の中 ${counts.in_range}、範囲の外（△） ${counts.out_of_range}、桁が違う（✕） ${counts.wild}、読めなかった呼び出し ${failedReadCount}`,
    `△ は範囲の外、✕ は上限の ${wildFactor} 倍より大きいか下限の ${wildFactor} 分の 1 より小さい（範囲を持たない材料は ${wildGramsWithoutRange} g より大きい）`,
  ].join("\n"),
);
