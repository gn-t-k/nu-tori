import {
  pushSyncWrites,
  type PushResults,
} from "../../../http/sync-routes/testing/push-sync-writes";
import { updateIngredientWrite } from "../../../ingredient/http/testing/update-ingredient-write";
import { updateDishWrite } from "./update-dish-write";

// 推定できた料理の名前を2回、量を1回（今の材料すべての比例の明細つき）、材料の量を1回、本物の書き込みで直す。
// 「消したら中身が残らない」の前提に使う。名前の2回目の書き込みの ID を返す（予定の取り消しの控えに使う）
export const correctDishByWrites = async (
  sessionToken: string,
  { dishId, ingredientIds }: { dishId: string; ingredientIds: readonly string[] },
): Promise<{ secondRenameWriteId: string }> => {
  const [firstIngredientId] = ingredientIds;
  if (firstIngredientId === undefined) {
    throw new Error("直す材料が無い");
  }
  const secondRename = updateDishWrite(dishId, { name: "かつ丼" });
  const { results } = await (
    await pushSyncWrites(sessionToken, {
      writes: [
        updateDishWrite(dishId, { name: "カツ丼" }),
        secondRename,
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
        updateIngredientWrite(firstIngredientId, 150),
      ],
    })
  ).json<PushResults>();
  if (results.some(({ result }) => result !== "applied")) {
    throw new Error(`直す書き込みが当たらなかった: ${JSON.stringify(results)}`);
  }
  return { secondRenameWriteId: secondRename.id };
};
