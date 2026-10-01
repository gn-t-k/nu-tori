import type Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { z } from "zod";
import nutrients from "../../../../../shared/nutrients.json";
import type {
  EstimationProvider,
  EstimationProviderReply,
  IdentifiedDishes,
} from "../../domain/estimation-provider";
import { requestStructuredOutput } from "./request-structured-output";

// ①: 写真（1食事に 1〜4 枚）から、料理と材料と量を読み取る
export const identifyDishes = async (
  client: Anthropic,
  userId: string,
  request: { photos: readonly ArrayBuffer[] },
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
        { type: "text", text: "この食事の料理と材料を答えてください。" },
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

const nutrientNames = Object.keys(nutrients);

const identifiedDishesSchema = z.object({
  dishes: z.array(
    z.object({
      name: z.string(),
      quantity: z.number(),
      unit: z.string(),
      ingredients: z.array(
        z.object({
          name: z.string(),
          quantity: z.number(),
          unit: z.string(),
          edibleGramsPerUnit: z.number(),
          foodCompositionQuery: z.string(),
          nutritionLabel: z
            .object({
              basisGrams: z.number(),
              // 栄養の名前をキーにした表は構造化出力で書けないので、名前と値の組の並びにする
              nutrients: z.array(z.object({ nutrient: z.enum(nutrientNames), amount: z.number() })),
            })
            .nullable(),
        }),
      ),
    }),
  ),
});

const toIdentifiedDishes = (output: z.output<typeof identifiedDishesSchema>): IdentifiedDishes => ({
  dishes: output.dishes.map((dish) => ({
    ...dish,
    ingredients: dish.ingredients.map(({ nutritionLabel, ...ingredient }) => ({
      ...ingredient,
      nutritionLabel:
        nutritionLabel === null
          ? undefined
          : {
              basisGrams: nutritionLabel.basisGrams,
              nutrients: Object.fromEntries(
                nutritionLabel.nutrients.map(({ nutrient, amount }) => [nutrient, amount]),
              ),
            },
    })),
  })),
});

const nutrientLines = Object.entries(nutrients)
  .map(([name, { unit }]) => `- ${name}（${unit}）`)
  .join("\n");

const system = `あなたは、食事の写真から、栄養を計算するための料理と材料の一覧を作る。写真は同じ1回の食事を写したもので、1〜4 枚ある。

## 料理と材料
- 料理ごとに、名前・量・単位を答える。単位はその料理を数える自然なもの（杯、皿、個、本、枚など）にする。
- 料理ごとに、材料を1つ以上答える。写真から見える材料に加え、調理に使ったと考えられる油や調味料も、写真から無理なく推定できる範囲で含める。
- 材料ごとに、名前・量・単位・1単位あたりの可食部の g を答える。単位が g なら 1、ml なら水に近いものは 1 とし、個・枚・本などは 1 つの可食部のおよその g にする。皮・骨・殻のように食べない部分は含めない。
- 量は写真の大きさと一般的な分量から、1人が実際に食べた分を見積もる。

## 成分表を引く語（foodCompositionQuery）
- 日本食品標準成分表（八訂）の食品名を引くための語を、空白で区切って答える。
- 成分表の書き方に寄せる。肉・魚・野菜の多くはひらがなで書かれる（鶏→にわとり、豚→ぶた、牛→うし、鮭→さけ、ご飯→こめ 水稲めし 精白米、サラダ油→調合油）。部位や調理の状態（生・ゆで・焼き・揚げ・皮なし・皮つき など）も語に含める。
- 例: 「にわとり 若どり もも 皮なし 焼き」「こめ 水稲めし 精白米」「ぶた ロース 脂身つき 焼き」「せん茶 浸出液」

## 栄養成分表示（nutritionLabel）
- パッケージなどの栄養成分表示が写っていて、読み取れる材料だけに付ける。読めない・無いときは null にする。
- basisGrams は表示の単位の g（100 g あたりなら 100。1 本あたりなら、その 1 本の g。ml は g とみなす）。
- nutrients は、書かれている栄養だけを、表示のままの値で答える。書かれていない栄養は含めない。栄養の名前と単位は次のとおり。
${nutrientLines}
- ナトリウムだけが書かれていて、食塩相当量が書かれていないときは、食塩相当量を含めない。

## 料理が無いとき
- 料理が写っていない、または見分けられないときは、dishes を空にする。理由は答えない。`;
