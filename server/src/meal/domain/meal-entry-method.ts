// 食事の入口。撮った（captured）か、撮っておいた写真を選んだ（picked）か、送った文章から作った（written）か
export type MealEntryMethod = PhotoMealEntryMethod | "written";

// 端末が食事を作る書き込みで送れる入口。文章の食事は、読み分けたサーバーだけが作る
export type PhotoMealEntryMethod = "captured" | "picked";

export const isPhotoMealEntryMethod = (value: string): value is PhotoMealEntryMethod =>
  value === "captured" || value === "picked";
