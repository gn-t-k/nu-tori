import type Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { z } from "zod";
import nutrients from "../../../../../shared/nutrients.json";
import type {
  DishToReestimate,
  EstimationProvider,
  EstimationProviderReply,
  IdentifiedDishes,
} from "../../domain/estimation-provider";
import { foodCompositionQuerySection } from "./food-composition-query-section";
import { identifiedDishSchema } from "./identified-dish-schema";
import { requestStructuredOutput } from "./request-structured-output";
import { toIdentifiedDishes } from "./to-identified-dishes";

// ①: 写真（1食事に 1〜4 枚）から、料理と材料と量を読み取る。推定し直しでは、写真と料理の今の値から、その料理1つを読み取る
export const identifyDishes = async (
  client: Anthropic,
  userId: string,
  request: Parameters<EstimationProvider["identifyDishes"]>[0],
  signal: AbortSignal,
): R.ResultAsync<
  EstimationProviderReply<IdentifiedDishes>,
  R.InferFailure<EstimationProvider["identifyDishes"]>
> => {
  // 写真を読むので長めにする。試み全体の上限（3 分）に、② の上限と合わせて収まる長さにする
  const timeLimitMs = 90_000;
  const requested = await requestStructuredOutput(
    client,
    {
      system,
      content: [
        ...request.photos.map((photo): Anthropic.ImageBlockParam => ({
          type: "image",
          // 端末が送る縮小版は JPEG に限る（受け口が JPEG だけを受け付ける）
          source: {
            type: "base64",
            media_type: "image/jpeg",
            data: Buffer.from(photo).toString("base64"),
          },
        })),
        {
          type: "text",
          text: match(request.target)
            .with({ type: "meal" }, () => mealInstruction)
            .with({ type: "dish" }, ({ dish }) =>
              toReestimationInstruction(dish, { hasPhotos: request.photos.length > 0 }),
            )
            .exhaustive(),
        },
      ],
      schema: identifiedDishesSchema,
      userId,
      timeLimitMs,
    },
    signal,
  );
  return R.pipe(
    requested,
    R.map(({ output, usage }) => ({ output: toIdentifiedDishes(output), usage })),
  );
};

// 写真の推定の指示
const mealInstruction = "この食事の料理と材料を答えてください。";

// 名前を直した・足した料理の推定し直しの指示（#332 の「① に渡すもの」）。使う人が直した材料と料理の量だけを渡す。
// 文章の食事は写真が無いので、名前だけから推定させる（#419 の「文章の食事」）
const toReestimationInstruction = (
  { name, correctedIngredients, correctedQuantity }: DishToReestimate,
  { hasPhotos }: { hasPhotos: boolean },
): string =>
  [
    `使う人が、この食事の料理の1つの名前を「${name}」にしました。この料理1つだけについて、量と材料を答えてください（dishes は1件）。${hasPhotos ? "写真にほかの料理が写っていても答えません。" : ""}`,
    hasPhotos
      ? "写真から見分けられなくても、名前と写真から無理なく推定できる範囲で答えてください。その名前の料理の材料を出せないときだけ、dishes を空にしてください。"
      : "この食事は文章から記録したもので、写真はありません。名前から、一般的な1人前を無理なく推定できる範囲で答えてください。その名前の料理の材料を出せないときだけ、dishes を空にしてください。",
    ...(correctedIngredients.length === 0
      ? []
      : [
          `使う人が直した材料: ${correctedIngredients
            .map(
              ({ name: ingredientName, quantity, unit }) => `${ingredientName} ${quantity} ${unit}`,
            )
            .join("、")}。新しい料理にも同じ材料があれば、この量を使ってください。`,
        ]),
    ...(correctedQuantity === undefined
      ? []
      : [
          `料理の量は ${correctedQuantity.value} ${correctedQuantity.unit}に決まっています。料理の量と単位はこのまま答え、材料への割り振りだけを推定してください。`,
        ]),
  ].join("\n");

const identifiedDishesSchema = z.object({ dishes: z.array(identifiedDishSchema) });

const nutrientLines = Object.entries(nutrients)
  .map(([name, { unit }]) => `- ${name}（${unit}）`)
  .join("\n");

const system = `あなたは、食事の写真から、栄養を計算するための料理と材料の一覧を作る。写真は同じ1回の食事を写したもので、1〜4 枚ある。

## 料理と材料
- 料理ごとに、名前・量・単位を答える。単位はその料理を数える自然なもの（杯、皿、個、本、枚など）にする。
- 料理ごとに、材料を1つ以上答える。写真から見える材料に加え、調理に使ったと考えられる油や調味料も、写真から無理なく推定できる範囲で含める。
- 材料ごとに、名前・量・単位・1単位あたりの可食部の g を答える。単位が g なら 1、ml なら水に近いものは 1 とし、個・枚・本などは 1 つの可食部のおよその g にする。皮・骨・殻のように食べない部分は含めない。
- 量は写真の大きさと一般的な分量から、1人が実際に食べた分を見積もる。

${foodCompositionQuerySection}

## 栄養成分表示（nutritionLabel）
- パッケージなどの栄養成分表示が写っていて、読み取れる材料だけに付ける。読めない・無いときは null にする。
- basisGrams は表示の単位の g（100 g あたりなら 100。1 本あたりなら、その 1 本の g。ml は g とみなす）。
- nutrients は、書かれている栄養だけを、表示のままの値で答える。書かれていない栄養は含めない。栄養の名前と単位は次のとおり。
${nutrientLines}
- ナトリウムだけが書かれていて、食塩相当量が書かれていないときは、食塩相当量を含めない。

## 料理が無いとき
- 料理が写っていない、または見分けられないときは、dishes を空にする。理由は答えない。`;
