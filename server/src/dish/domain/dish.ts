// 食事に写っている料理。サーバーが推定の完了で作る
export type Dish = {
  id: string;
  mealId: string;
  name: string;
  quantity: number;
  unit: string;
  // 一意にしない。同じ並び順は ID の順で並べる
  positionInMeal: number;
  // ヘルスケアの同期の版。作ったときは 1
  version: number;
};
