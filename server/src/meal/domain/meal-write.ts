import type { Meal } from "./meal";

// 端末から届く食事の書き込み。入口は受け口で値を確かめず、ドメイン層で確かめる
export type MealWrite = { id: string } & (
  | { type: "create_meal"; meal: Omit<Meal, "entryMethod"> & { entryMethod: string } }
  | { type: "delete_meal"; mealId: string }
  // 直すのは撮った時刻だけ。時差・送った時刻・入口は変えない
  | { type: "update_meal"; mealId: string; eatenAt: Date }
);

// 書き込みの type の一覧。ドメインの種類の見分けと、受け口の見分けが、ここを使う
export const mealWriteTypes: readonly string[] = Object.keys({
  create_meal: true,
  delete_meal: true,
  update_meal: true,
  // キーを書き込みの型に合わせ、type を足したときの足し忘れを型エラーにする
} satisfies Record<MealWrite["type"], true>);
