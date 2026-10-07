// 端末から届く料理の書き込み。入口は受け口で値を確かめず、ドメイン層で確かめる
export type DishWrite = { id: string } &
  // 料理を足す。料理の ID は端末が振る。量と材料は推定し直しで入る
  (
    | { type: "create_dish"; dishId: string; mealId: string; name: string; positionInMeal: number }
    | { type: "delete_dish"; dishId: string }
    | {
        type: "update_dish";
        dishId: string;
        name: string;
        // 名前だけを直すときは省く。量を直すときは名前と量を運ぶ
        quantity: DishQuantityCorrection | undefined;
      }
  );

// 直した料理の量と、端末が同じ割合で変えた今の材料の量（比例）。サーバーは割合を計算し直さない
export type DishQuantityCorrection = {
  value: number;
  proportionedIngredients: readonly { ingredientId: string; quantity: number }[];
};

// 書き込みの type の一覧。ドメインの種類の見分けと、受け口の見分けが、ここを使う
export const dishWriteTypes: readonly string[] = Object.keys({
  create_dish: true,
  delete_dish: true,
  update_dish: true,
  // キーを書き込みの型に合わせ、type を足したときの足し忘れを型エラーにする
} satisfies Record<DishWrite["type"], true>);
