import type { QuantitySource } from "../../domain/quantity-source";

// 食事に写っている料理の今の値。サーバーが推定の完了で作り、端末が名前と量を直す
export type Dish = {
  id: string;
  mealId: string;
  // 今の名前。名前の修正のうち受け取った順でいちばんあとのもの、無ければ作ったときの名前
  name: string;
  // 今の量。量を持つ当てた推定が無い料理（推定し直しが一度も当たっていない料理）は持たない
  quantity: DishQuantity | undefined;
  // 一意にしない。同じ並び順は ID の順で並べる
  positionInMeal: number;
  // ヘルスケアの同期の版。行に持たず、料理を直した出来事の数から出す（作ったときは 1）
  version: number;
};

export type DishQuantity = {
  // 料理の量の修正のうち受け取った順でいちばんあとのもの、無ければ量を持ついちばん新しい当てた推定の量
  value: number;
  // 量を持ついちばん新しい当てた推定の単位。直しても変わらない
  unit: string;
  // 料理の量の修正があれば corrected
  source: QuantitySource;
};

// 料理を作るときに書く値。量と単位は当てた推定（DishEstimationApplication）が持ち、版は出来事から出す
export type NewDish = Pick<Dish, "id" | "mealId" | "name" | "positionInMeal">;

// 推定の結果を料理に当てたこと。推定した量と単位を持つ。
// 推定し直しで、量を直してあった料理（直した量を固定する）と、通らなかった推定（料理なし・推定できなかった）は量を持たない
export type DishEstimationApplication = {
  dishId: string;
  estimationId: string;
  estimatedQuantity: { quantity: number; unit: string } | undefined;
};
