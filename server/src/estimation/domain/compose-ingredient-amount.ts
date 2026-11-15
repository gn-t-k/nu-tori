import type { EstimatedDish } from "./estimated-dish";
import type { IdentifiedIngredient } from "./estimation-provider";

// ① の材料の名前と量を、記録する材料の形にする。栄養の出どころによらず同じ
export const composeIngredientAmount = (
  ingredient: Pick<IdentifiedIngredient, "name" | "quantity" | "unit" | "edibleGrams">,
): Pick<
  EstimatedDish["ingredients"][number],
  "name" | "quantity" | "unit" | "edibleGramsPerUnit"
> => ({
  name: ingredient.name,
  quantity: ingredient.quantity,
  unit: ingredient.unit,
  // 栄養に使う g は ① が直接見積もった合計で、量と掛け合わせて作らない（量と1単位あたりを別々に答えさせると、重ねて答えたときに桁が跳ねる）
  edibleGramsPerUnit: ingredient.edibleGrams / ingredient.quantity,
});
