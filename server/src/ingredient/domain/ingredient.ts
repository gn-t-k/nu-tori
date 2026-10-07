import type { NutrientName } from "../../domain/food-composition/nutrient-name";
import type { QuantitySource } from "../../domain/quantity-source";

// 料理を構成する材料の今の値。サーバーが推定の完了で作り、端末が量を直す
export type Ingredient = {
  id: string;
  dishId: string;
  // この材料が属する当てた推定。今の材料は、料理のいちばん新しい当てた推定の材料
  estimationId: string;
  name: string;
  // 今の量。直した量と料理の量に比例させた量のうち受け取った順でいちばんあとのもの、無ければ推定した量
  quantity: number;
  // 直した量があれば corrected。比例させた量は出どころを変えない
  quantitySource: QuantitySource;
  unit: string;
  edibleGramsPerUnit: number;
  // 一意にしない。同じ並び順は ID の順で並べる
  positionInDish: number;
  nutrientSource: IngredientNutrientSource;
  // 基準あたりの値（成分表と AI の推定は可食部 100 g、栄養成分表示は表示の単位）。不明の項目は持たない
  nutrients: Readonly<Partial<Record<NutrientName, number>>>;
};

// 推定の完了で材料を作るときに書く値。量は推定した量で、出どころは推定したまま
export type NewIngredient = Omit<Ingredient, "quantitySource">;

// 栄養の値の出どころ。成分表は引いた食品番号、栄養成分表示は表示の単位あたりの可食部の g を持つ
export type IngredientNutrientSource =
  | { type: "nutrition_label"; labelBasisGrams: number }
  | { type: "food_composition"; foodNumber: string }
  | { type: "estimated" };
