// 見送った・保留した予定は推定を始めない。始めた予定は、完了か断念が来るまで推定中
export type MealEstimationScheduleProgress = MealEstimationScheduleState["progress"];

// 予定の進み具合と、推定を始めた予定だけが持つ始めた推定
export type MealEstimationScheduleState =
  | { progress: "waiting" | "deferred" | "held" }
  | { progress: "estimating" | "estimated" | "no_dishes" | "abandoned"; estimationId: string };
