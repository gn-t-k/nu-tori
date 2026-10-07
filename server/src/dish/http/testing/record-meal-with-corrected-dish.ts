import { recordPhotographedMeal } from "../../../estimation/http/testing/record-photographed-meal";
import { runEstimationAlarm } from "../../../estimation/http/testing/run-estimation-alarm";
import {
  pullSyncChanges,
  type PullResult,
} from "../../../http/sync-routes/testing/pull-sync-changes";
import {
  pushSyncWrites,
  type PushResults,
} from "../../../http/sync-routes/testing/push-sync-writes";
import { updateMealWrite } from "../../../meal/http/testing/update-meal-write";
import { correctDishByWrites } from "./correct-dish-by-writes";
import { reestimateRenamedDish } from "./reestimate-renamed-dish";

// 写真1枚の食事を推定し、時刻を2回直し、1つめの料理の名前と量と材料を直して、推定し直しで材料を置き換える。2つめの料理は直さない。
// 「消したら中身が残らない」の前提に使う。名前を2回直すので、1回目の名前で待った予定は、2回目の名前の書き込みが取り消す。
// 推定の提供元の差し替えと時計は、呼ぶ側が先に用意する
export const recordMealWithCorrectedDish = async (accountId: string, sessionToken: string) => {
  const mealId = await recordPhotographedMeal(sessionToken);
  await runEstimationAlarm(accountId);
  const estimated = (await (await pullSyncChanges(sessionToken)).json<PullResult>()).changes;
  const [dishId, untouchedDishId] = estimated
    .filter(({ kind }) => kind === "dish")
    .map(({ recordId }) => recordId);
  if (dishId === undefined || untouchedDishId === undefined) {
    throw new Error("推定で料理が2つできていない");
  }
  const ingredientIdsOf = (id: string) =>
    estimated
      .filter(({ kind, record }) => kind === "ingredient" && record["dishId"] === id)
      .map(({ recordId }) => recordId);
  const previousIngredientIds = ingredientIdsOf(dishId);
  const corrected = await pushSyncWrites(sessionToken, {
    writes: [
      updateMealWrite(mealId, Date.now() - 10 * 60_000),
      updateMealWrite(mealId, Date.now() - 20 * 60_000),
    ],
  });
  if ((await corrected.json<PushResults>()).results.some(({ result }) => result !== "applied")) {
    throw new Error("時刻を直す書き込みが当たらなかった");
  }
  await correctDishByWrites(sessionToken, { dishId, ingredientIds: previousIngredientIds });
  const replacingIngredientIds = await reestimateRenamedDish(accountId, sessionToken, dishId);
  return {
    mealId,
    dishId,
    untouchedDishId,
    // 直した料理の、前の推定の材料と、置き換えた材料
    ingredientIds: [...previousIngredientIds, ...replacingIngredientIds],
    untouchedIngredientIds: ingredientIdsOf(untouchedDishId),
  };
};
