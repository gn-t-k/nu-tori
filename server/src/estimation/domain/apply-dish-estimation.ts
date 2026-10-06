import type { DishStore } from "../../dish/domain/dish-store";
import { findNewestActiveSchedule } from "../../dish-estimation-status/domain/dish-estimation-schedule";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import type { IngredientStore } from "../../ingredient/domain/ingredient-store";
import type { EstimatedDish } from "./estimated-dish";

// 料理が対象の推定が終わったとき（完了か断念）に、#332 の「推定し直しの当て方（書く順）」で料理に当てる。
// 当てるのは、その推定の予定が、料理の取り消していない予定のうちいちばん新しいときだけで、ほかは捨てる
// （待つあいだに名前をまた直していた。捨てたことは出来事に持たない）。料理を消していたら、つなぎが無く、ここに来ない。
// estimated が undefined なら、通らなかった（料理なし・推定できなかった）として当てる: 量と材料を持たない当てた推定を足し、
// 名前と前の量を残し、今の材料を無くす。量を直してあれば、届いた量を当てず、直した量を固定する（届いた割り振りだけを材料に使う）。
// 前の材料は行を消さずに前の当てた推定に属したまま残り、削除の印として届くので、その変更も足す。
// 推定の状態の変更は推定の書き込みの口が run のあとに足すので、ここで足す変更より後に並ぶ
export const applyDishEstimation = (
  stores: {
    dish: DishStore;
    ingredient: IngredientStore;
    dishEstimationStatus: DishEstimationStatusStore;
  },
  addChange: (change: RecordChangeTarget<"dish" | "ingredient">) => void,
  {
    dishId,
    estimationId,
    estimated,
  }: {
    dishId: string;
    estimationId: string;
    estimated: EstimatedDish | undefined;
  },
): void => {
  const newest = findNewestActiveSchedule(stores.dishEstimationStatus.findSchedulesOfDish(dishId));
  if (newest?.estimationId !== estimationId) {
    return;
  }
  const dish = stores.dish.find(dishId);
  if (dish === undefined) {
    throw new Error(`推定し直しの予定につながっている料理が無い: ${dishId}`);
  }
  const previousIngredientIds = stores.ingredient.findCurrentIdsOfDish(dishId);
  stores.dish.insertEstimationApplication({
    dishId,
    estimationId,
    estimatedQuantity:
      estimated === undefined || dish.quantity?.source === "corrected"
        ? undefined
        : { quantity: estimated.quantity, unit: estimated.unit },
  });
  const ingredients = (estimated?.ingredients ?? []).map((ingredient, positionInDish) => ({
    ...ingredient,
    id: crypto.randomUUID(),
    dishId,
    estimationId,
    positionInDish,
  }));
  for (const ingredient of ingredients) {
    stores.ingredient.insert(ingredient);
  }
  addChange({ recordType: "dish", recordId: dishId });
  for (const { id } of ingredients) {
    addChange({ recordType: "ingredient", recordId: id });
  }
  for (const recordId of previousIngredientIds) {
    addChange({ recordType: "ingredient", recordId });
  }
};
