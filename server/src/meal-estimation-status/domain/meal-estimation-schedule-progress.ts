// 見送った予定は推定を始めない。始めた予定は、完了か断念が来るまで推定中
export type MealEstimationScheduleProgress =
  | "waiting"
  | "deferred"
  | "estimating"
  | "estimated"
  | "no_dishes"
  | "abandoned";
