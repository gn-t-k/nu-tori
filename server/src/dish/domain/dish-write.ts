// 端末から届く料理の書き込み。入口は受け口で値を確かめず、ドメイン層で確かめる
export type DishWrite = { id: string } & { type: "delete_dish"; dishId: string };

// 書き込みの type の一覧。ドメインの種類の見分けと、受け口の見分けが、ここを使う
export const dishWriteTypes: readonly string[] = Object.keys({
  delete_dish: true,
  // キーを書き込みの型に合わせ、type を足したときの足し忘れを型エラーにする
} satisfies Record<DishWrite["type"], true>);
