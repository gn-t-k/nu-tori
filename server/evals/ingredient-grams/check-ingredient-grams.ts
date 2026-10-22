import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { toWrittenMealsRequest } from "../../src/estimation/domain/to-written-meals-request";
import type { IdentifiedIngredient } from "../../src/estimation/domain/estimation-provider";
import { identifyDishes } from "../../src/estimation/durable-object/create-estimation-provider/identify-dishes";
import { identifyWrittenMeals } from "../../src/estimation/durable-object/create-estimation-provider/identify-written-meals";
import { missingEvalApiKeyMessage, readEvalApiKey } from "../read-eval-api-key";

// ① が答える材料の g（食べた分の可食部の g）が、ありうる範囲に収まるかを、本番と同じ指示とモデルで確かめる（#517）。
// 量と1単位あたりの g を別々に答えさせていたとき、重ねて答えて桁が跳ねた（卵 50 g × 50 = 2,500 g）。
// 同じ食事を何回か読ませ、材料ごとの g と、範囲から外れた数、桁が違う数を出す。
// 回し方（手で。CI と scripts/check には入れない）: server/ で `pnpm exec tsx evals/ingredient-grams/check-ingredient-grams.ts`。
// 鍵の置き場は read-eval-api-key.ts。文章は作り話だけにする（公開リポジトリ）。
// 手元の写真も読ませるときは、JPEG を .scratch/ingredient-grams/（gitignore）に置く。範囲は持たないので、桁だけを見る
const runs = 5;

// 範囲の外でも、上限の 3 倍までと下限の 3 分の 1 までは見積もりの揺れとみなし、それより外を桁が違うと数える
const wildFactor = 3;

// 範囲を持たない材料（調味料や、手元の写真の材料）で、桁が違うとみなす g
const wildGramsWithoutRange = 1000;

type ExpectedIngredient = {
  label: string;
  // 材料の名前にどれかが入っていれば、この材料とみなす。1つの材料は、並びで最初に当たった1つにだけ数える
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
  keywords: ["飯", "ごはん", "ライス"],
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
    expected: [
      {
        label: "鶏むね肉 200 g",
        keywords: ["鶏むね", "鶏肉", "むね肉", "とり肉"],
        minGrams: 130,
        maxGrams: 220,
      },
    ],
  },
  {
    body: "サラダにオリーブオイルを大さじ1かけた",
    expected: [
      {
        label: "オリーブオイル 大さじ 1",
        keywords: ["オリーブ", "オイル"],
        minGrams: 9,
        maxGrams: 16,
      },
    ],
  },
  {
    body: "緑茶のペットボトル500mlを1本",
    expected: [{ label: "緑茶 500 ml", keywords: ["茶"], minGrams: 450, maxGrams: 550 }],
  },
  // kg と L で書いた量。g と ml に直すところで桁を外さないかを見る
  {
    body: "スポーツドリンクを1.5L飲んだ",
    expected: [
      {
        label: "スポーツドリンク 1.5 L",
        keywords: ["スポーツドリンク", "スポーツ飲料"],
        minGrams: 1350,
        maxGrams: 1650,
      },
    ],
  },
  {
    body: "すいかを1kg食べた",
    expected: [
      { label: "すいか 1 kg", keywords: ["すいか", "スイカ"], minGrams: 550, maxGrams: 1050 },
    ],
  },
];

const committedPhotoCases: readonly { file: string; expected: readonly ExpectedIngredient[] }[] = [
  {
    file: path.join(import.meta.dirname, "../../e2e/photos/oyakodon.jpg"),
    expected: [
      { label: "卵", keywords: ["卵", "たまご", "玉子"], minGrams: 40, maxGrams: 140 },
      { label: "ご飯", keywords: rice.keywords, minGrams: 120, maxGrams: 350 },
      {
        label: "鶏肉",
        keywords: ["鶏もも", "鶏むね", "鶏肉", "もも肉", "とり肉"],
        minGrams: 40,
        maxGrams: 180,
      },
    ],
  },
];

const localPhotoDirectory = path.join(import.meta.dirname, "../../.scratch/ingredient-grams");

const apiKey = readEvalApiKey();
if (apiKey === undefined) {
  throw new Error(missingEvalApiKeyMessage);
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

const judgeAgainstRange = (grams: number, { minGrams, maxGrams }: ExpectedIngredient): Verdict => {
  if (grams >= minGrams && grams <= maxGrams) {
    return "in_range";
  }
  return grams > maxGrams * wildFactor || grams < minGrams / wildFactor ? "wild" : "out_of_range";
};

// 1回分の答えの見立て。failed は呼び出しが読めなかった回
type JudgedRun =
  | { type: "failed" }
  | {
      type: "read";
      ingredients: readonly IdentifiedIngredient[];
      // expected と同じ並び。当たる材料が無ければ unmatched、あれば g の和と見立て
      judgedExpected: readonly (
        | { type: "unmatched" }
        | { type: "matched"; grams: number; verdict: Verdict }
      )[];
      // 範囲を持たない材料のうち、桁が違うもの
      wildWithoutRange: readonly IdentifiedIngredient[];
    };

const judgeRun = (answer: ReadIngredients, expected: readonly ExpectedIngredient[]): JudgedRun => {
  if (answer === undefined) {
    return { type: "failed" };
  }
  const assigned = answer.map(({ name }) =>
    expected.findIndex(({ keywords }) => keywords.some((keyword) => name.includes(keyword))),
  );
  return {
    type: "read",
    ingredients: answer,
    judgedExpected: expected.map((ingredient, index) => {
      const matched = answer.filter((_, position) => assigned[position] === index);
      if (matched.length === 0) {
        return { type: "unmatched" };
      }
      const grams = matched.reduce((sum, { edibleGrams }) => sum + edibleGrams, 0);
      return { type: "matched", grams, verdict: judgeAgainstRange(grams, ingredient) };
    }),
    wildWithoutRange: answer.filter(
      ({ edibleGrams }, position) =>
        assigned[position] === -1 && edibleGrams > wildGramsWithoutRange,
    ),
  };
};

const localPhotoFiles = await readdir(localPhotoDirectory)
  .then((names) => names.filter((name) => /\.jpe?g$/i.test(name)).toSorted())
  .catch(() => []);

const cases = await Promise.all([
  ...writtenCases.map(async ({ body, expected }) => ({
    title: body,
    isLocalPhoto: false,
    expected,
    answers: await readRuns(() => readWrittenOnce(body)),
  })),
  ...committedPhotoCases.map(async ({ file, expected }) => {
    const photo = await readPhoto(file);
    return {
      title: `写真 ${path.basename(file)}`,
      isLocalPhoto: false,
      expected,
      answers: await readRuns(() => readPhotoOnce(photo)),
    };
  }),
  ...localPhotoFiles.map(async (name) => {
    const photo = await readPhoto(path.join(localPhotoDirectory, name));
    return {
      title: `手元の写真 ${name}`,
      isLocalPhoto: true,
      expected: [],
      answers: await readRuns(() => readPhotoOnce(photo)),
    };
  }),
]);

const judgedCases = cases.map(({ answers, ...rest }) => ({
  ...rest,
  judgedRuns: answers.map((answer) => judgeRun(answer, rest.expected)),
}));

const marks: Readonly<Record<Verdict, string>> = { in_range: "", out_of_range: " △", wild: " ✕" };

const formatGrams = (grams: number): string => String(Math.round(grams * 10) / 10);

const formatIngredient = ({ name, quantity, unit, edibleGrams }: IdentifiedIngredient): string =>
  `${name} ${quantity} ${unit} = ${formatGrams(edibleGrams)} g`;

// 範囲を持つ材料は、材料ごとに1行で、回ごとの g を並べる
const rows = judgedCases.flatMap(({ title, expected, judgedRuns }) =>
  expected.map((ingredient, index) => {
    const cells = judgedRuns.map((judgedRun) => {
      if (judgedRun.type === "failed") {
        return "失敗";
      }
      const judged = judgedRun.judgedExpected[index];
      return judged === undefined || judged.type === "unmatched"
        ? "無い"
        : `${formatGrams(judged.grams)}${marks[judged.verdict]}`;
    });
    return `| ${title} | ${ingredient.label} | ${ingredient.minGrams}〜${ingredient.maxGrams} | ${cells.join(" | ")} |`;
  }),
);

// 手元の写真は範囲を持たないので、読んだ材料をそのまま並べる
const localLines = judgedCases
  .filter(({ isLocalPhoto }) => isLocalPhoto)
  .flatMap(({ title, judgedRuns }) =>
    judgedRuns.map(
      (judgedRun, run) =>
        `- ${title} ${run + 1}回目: ${
          judgedRun.type === "failed"
            ? "失敗"
            : judgedRun.ingredients.map(formatIngredient).join("、")
        }`,
    ),
  );

const wildLines = judgedCases.flatMap(({ title, judgedRuns }) =>
  judgedRuns.flatMap((judgedRun, run) =>
    judgedRun.type === "failed"
      ? []
      : judgedRun.wildWithoutRange.map(
          (ingredient) => `- ${title} ${run + 1}回目: ${formatIngredient(ingredient)}${marks.wild}`,
        ),
  ),
);

const allRuns = judgedCases.flatMap(({ judgedRuns }) => judgedRuns);
const answeredRuns = allRuns.filter((judgedRun) => judgedRun.type === "read");
const judgedExpected = answeredRuns.flatMap((judgedRun) => judgedRun.judgedExpected);
const countVerdict = (verdict: Verdict): number =>
  judgedExpected.filter((judged) => judged.type === "matched" && judged.verdict === verdict).length;
const wildCount =
  countVerdict("wild") +
  answeredRuns.reduce((sum, { wildWithoutRange }) => sum + wildWithoutRange.length, 0);
const unmatchedCount = judgedExpected.filter(({ type }) => type === "unmatched").length;
const failedCount = allRuns.length - answeredRuns.length;

console.log(
  [
    `| 食事 | 材料 | ありうる g | ${Array.from({ length: runs }, (_, run) => `${run + 1}回目`).join(" | ")} |`,
    `|---|---|---|${"---|".repeat(runs)}`,
    ...rows,
    "",
    ...localLines,
    ...wildLines,
    "",
    `範囲の中 ${countVerdict("in_range")}、範囲の外（△） ${countVerdict("out_of_range")}、桁が違う（✕） ${wildCount}、当たる材料が無い ${unmatchedCount}、読めなかった呼び出し ${failedCount}`,
    `△ は範囲の外、✕ は上限の ${wildFactor} 倍より大きいか下限の ${wildFactor} 分の 1 より小さい（範囲を持たない材料は ${wildGramsWithoutRange} g より大きい）`,
  ].join("\n"),
);
