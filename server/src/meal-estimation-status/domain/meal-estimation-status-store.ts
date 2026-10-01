export type MealEstimationStatusStore = {
  // 食事につながっている推定の予定ごとの、予定から先の出来事
  findSchedulesOfMeal: (mealId: string) => {
    dueAt: Date;
    // 見送った予定は推定を始めない。始めた予定は、完了か断念が来るまで推定中
    progress: "waiting" | "deferred" | "estimating" | "estimated" | "no_dishes" | "abandoned";
  }[];
};
