import type Anthropic from "@anthropic-ai/sdk";
import { R } from "@praha/byethrow";
import { z } from "zod";
import {
  type EstimationProviderFailure,
  type EstimationProviderReply,
  EstimationProviderInvalidResponseError,
  type IngredientMatch,
  type IngredientMatchRequest,
  type MatchedIngredients,
} from "../../domain/estimation-provider";
import { requestStructuredOutput } from "./request-structured-output";

// ②: 栄養成分表示の無い材料ごとに、成分表の候補から食品番号を選ぶ。選べなければ主な栄養を推定する（文字だけの呼び出し）
export const matchIngredients = async (
  client: Anthropic,
  userId: string,
  request: IngredientMatchRequest,
  signal: AbortSignal,
): R.ResultAsync<EstimationProviderReply<MatchedIngredients>, EstimationProviderFailure> => {
  // 文字だけで答えも短いので、① より短くする
  const timeLimitMs = 60_000;
  const requested = await requestStructuredOutput(
    client,
    {
      system,
      content: [{ type: "text", text: describeIngredients(request) }],
      schema: matchedIngredientsSchema,
      userId,
      timeLimitMs,
    },
    signal,
  );
  if (R.isFailure(requested)) {
    return requested;
  }
  const { output, usage } = requested.value;
  const matches = output.ingredients.map(toIngredientMatch);
  const ingredients = matches.filter((match) => match !== undefined);
  // 食品番号も推定した栄養も無い答えは、読めない応答にする
  return ingredients.length === matches.length
    ? R.succeed({ output: { ingredients }, usage })
    : R.fail(new EstimationProviderInvalidResponseError({ usage }));
};

const matchedIngredientsSchema = z.object({
  ingredients: z.array(
    z.object({
      // 候補から選んだ食品番号。選べないときは null
      foodNumber: z.string().nullable(),
      // 食品番号が null のときの、可食部 100 g あたりの主な栄養
      estimatedNutrients: z
        .object({
          energy_kcal: z.number(),
          protein_g: z.number(),
          fat_g: z.number(),
          carbohydrate_g: z.number(),
          fiber_g: z.number(),
          salt_equivalent_g: z.number(),
        })
        .nullable(),
    }),
  ),
});

const toIngredientMatch = ({
  foodNumber,
  estimatedNutrients,
}: z.output<typeof matchedIngredientsSchema>["ingredients"][number]):
  | IngredientMatch
  | undefined => {
  if (foodNumber !== null) {
    return { source: "food_composition", foodNumber };
  }
  return estimatedNutrients === null
    ? undefined
    : { source: "estimated", nutrients: estimatedNutrients };
};

// 成分表の食品名は階層を全角スペースでつなぐので、読みやすいよう半角にする
const describeIngredients = ({ ingredients }: IngredientMatchRequest): string =>
  ingredients
    .map(({ name, foodCompositionQuery, candidates }, index) =>
      [
        `材料 ${index + 1}: ${name}`,
        `成分表を引く語: ${foodCompositionQuery}`,
        candidates.length === 0
          ? "候補: なし"
          : [
              "候補（食品番号 食品名）:",
              ...candidates.map(
                (candidate) => `- ${candidate.foodNumber} ${candidate.name.replaceAll("　", " ")}`,
              ),
            ].join("\n"),
      ].join("\n"),
    )
    .join("\n\n");

const system = `あなたは、材料ごとに、日本食品標準成分表（八訂）の食品を選ぶ。

## 入力
材料の一覧。材料ごとに、名前、成分表を引く語、成分表から探した候補（食品番号と食品名）がある。

## 答え方
- 材料と同じ並び・同じ数で、材料ごとに1つ答える。
- 候補の中に、その材料と同じ食品で、調理の状態（生・ゆで・焼き・揚げなど）と部位も合うものがあれば、その食品番号を foodNumber に答える。食品番号は、必ず候補にあるものから選ぶ。作らない。
- 合うものが無い、または候補が無いときは、foodNumber を null にし、estimatedNutrients に可食部 100 g あたりの次の栄養を、一般的な値で推定して答える。energy_kcal（kcal）、protein_g（g）、fat_g（g）、carbohydrate_g（g）、fiber_g（g）、salt_equivalent_g（g）。
- 食品番号を選んだときは、estimatedNutrients を null にする。`;
