import type { NutrientName } from "../../domain/food-composition/nutrient-name";

// 料理を構成する材料。サーバーが推定の完了で作る
export type Ingredient = {
  id: string;
  dishId: string;
  // この材料が属する当てた推定。今の材料は、料理のいちばん新しい当てた推定の材料
  estimationId: string;
  name: string;
  quantity: number;
  unit: string;
  edibleGramsPerUnit: number;
  // 一意にしない。同じ並び順は ID の順で並べる
  positionInDish: number;
  nutrientSource: IngredientNutrientSource;
  // 基準あたりの値（成分表と AI の推定は可食部 100 g、栄養成分表示は表示の単位）。不明の項目は持たない
  nutrients: Readonly<Partial<Record<NutrientName, number>>>;
};

// 栄養の値の出どころ。成分表は引いた食品番号、栄養成分表示は表示の単位あたりの可食部の g を持つ
export type IngredientNutrientSource =
  | { type: "nutrition_label"; labelBasisGrams: number }
  | { type: "food_composition"; foodNumber: string }
  | { type: "estimated" };
