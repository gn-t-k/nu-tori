// 食事に写っている料理の今の値。サーバーが推定の完了で作る
export type Dish = {
  id: string;
  mealId: string;
  name: string;
  // 量を持ついちばん新しい当てた推定の量と単位
  quantity: number;
  unit: string;
  // 一意にしない。同じ並び順は ID の順で並べる
  positionInMeal: number;
  // ヘルスケアの同期の版。行に持たず、料理を直した出来事の数から出す（作ったときは 1）
  version: number;
};

// 料理を作るときに書く値。量と単位は当てた推定（DishEstimationApplication）が持ち、版は出来事から出す
export type NewDish = Pick<Dish, "id" | "mealId" | "name" | "positionInMeal">;

// 推定の結果を料理に当てたこと。推定した量と単位を持つ
export type DishEstimationApplication = {
  dishId: string;
  estimationId: string;
  estimatedQuantity: { quantity: number; unit: string };
};
