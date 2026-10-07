import type { RecordId } from "../../domain/record-id";
import type { DishStore } from "../../dish/domain/dish-store";
import type { IngredientStore } from "../../ingredient/domain/ingredient-store";
import type { DishToReestimate } from "./estimation-provider";

// ① に渡す、推定し直す料理の今の値。試みを書くときに読む（やり直しのたびに、その時点の今の値を渡す）。
// 推定したままの材料と、比例で変えた材料は渡さない
export const computeDishToReestimate = (
  stores: { dish: DishStore; ingredient: IngredientStore },
  dishId: RecordId,
): DishToReestimate => {
  const dish = stores.dish.find(dishId);
  if (dish === undefined) {
    throw new Error(`推定し直しの予定につながっている料理が無い: ${dishId}`);
  }
  return {
    name: dish.name,
    correctedIngredients: stores.ingredient
      .findCurrentIdsOfDish(dishId)
      .map((id) => stores.ingredient.find(id))
      .filter((ingredient) => ingredient !== undefined)
      .filter(({ quantitySource }) => quantitySource === "corrected")
      .toSorted((a, b) => a.positionInDish - b.positionInDish || a.id.localeCompare(b.id))
      .map(({ name, quantity, unit }) => ({ name, quantity, unit })),
    correctedQuantity:
      dish.quantity?.source === "corrected"
        ? { value: dish.quantity.value, unit: dish.quantity.unit }
        : undefined,
  };
};
