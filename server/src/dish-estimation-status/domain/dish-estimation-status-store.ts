import type { DishEstimationSchedule } from "./dish-estimation-schedule";

export type DishEstimationStatusStore = {
  // 料理につながっている推定の予定（取り消した予定も）ごとの、予定から先の出来事
  findSchedulesOfDish: (dishId: string) => DishEstimationSchedule[];
};
