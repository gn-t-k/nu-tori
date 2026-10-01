// 食事の入口。撮った（captured）か、撮っておいた写真を選んだ（picked）か
export type MealEntryMethod = "captured" | "picked";

export const isMealEntryMethod = (value: string): value is MealEntryMethod =>
  value === "captured" || value === "picked";
