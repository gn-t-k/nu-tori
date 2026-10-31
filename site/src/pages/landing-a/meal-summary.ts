import type { exampleTextMeals } from "./example-text-meals";

// 食事のカードに出す料理の名前と栄養。撮った食事にも書いた食事にもある
export type MealSummary = Pick<(typeof exampleTextMeals)[number], "dish" | "totals">;
