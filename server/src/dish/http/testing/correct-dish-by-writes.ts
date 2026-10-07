import {
  pushSyncWrites,
  type PushResults,
} from "../../../http/sync-routes/testing/push-sync-writes";
import { updateIngredientWrite } from "../../../ingredient/http/testing/update-ingredient-write";
import { updateDishWrite } from "./update-dish-write";

// 推定できた料理の材料の量を1回直してから、名前と量（今の材料すべての比例の明細つき）を1つの書き込みで直す。
// 「消したら中身が残らない」の前提に使う。名前を直すと料理が推定し直しを待ち、そのあとの直しは断られるので、名前は最後に1回だけ直す
export const correctDishByWrites = async (
  sessionToken: string,
  { dishId, ingredientIds }: { dishId: string; ingredientIds: readonly string[] },
): Promise<void> => {
  const [firstIngredientId] = ingredientIds;
  if (firstIngredientId === undefined) {
    throw new Error("直す材料が無い");
  }
  const { results } = await (
    await pushSyncWrites(sessionToken, {
      writes: [
        updateIngredientWrite(firstIngredientId, 150),
        updateDishWrite(dishId, {
          name: "かつ丼",
          quantity: {
            value: 1.5,
            proportionedIngredients: ingredientIds.map((ingredientId) => ({
              ingredientId,
              quantity: 120,
            })),
          },
        }),
      ],
    })
  ).json<PushResults>();
  if (results.some(({ result }) => result !== "applied")) {
    throw new Error(`直す書き込みが当たらなかった: ${JSON.stringify(results)}`);
  }
};
