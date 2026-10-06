// 端末から届く材料の書き込み。入口は受け口で値を確かめず、ドメイン層で確かめる
export type IngredientWrite = { id: string } & {
  type: "update_ingredient";
  ingredientId: string;
  quantity: number;
};

// 書き込みの type の一覧。ドメインの種類の見分けと、受け口の見分けが、ここを使う
export const ingredientWriteTypes: readonly string[] = Object.keys({
  update_ingredient: true,
  // キーを書き込みの型に合わせ、type を足したときの足し忘れを型エラーにする
} satisfies Record<IngredientWrite["type"], true>);
