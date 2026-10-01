export type MealEstimationStatusStore = {
  // 食事につながっている推定の予定ごとの、予定から先の出来事があるか
  findSchedulesOfMeal: (mealId: string) => {
    dueAt: Date;
    isDeferred: boolean;
    isStarted: boolean;
    completion: "estimated" | "no_dishes" | undefined;
    isAbandoned: boolean;
  }[];
};
