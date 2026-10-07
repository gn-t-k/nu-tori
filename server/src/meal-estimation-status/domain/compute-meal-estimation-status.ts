import { match } from "ts-pattern";
import type { MealEstimationStatus } from "./meal-estimation-status";
import type { MealEstimationStatusStore } from "./meal-estimation-status-store";

export const computeMealEstimationStatus = (
  schedules: ReturnType<MealEstimationStatusStore["findSchedulesOfMeal"]>,
): MealEstimationStatus => {
  const latest = schedules.toSorted((a, b) => b.dueAt.getTime() - a.dueAt.getTime())[0];
  if (latest === undefined) {
    return "awaiting_photos";
  }
  return match(latest.progress)
    .returnType<MealEstimationStatus>()
    .with("waiting", () =>
      // 見送ると次の日の予定を足すので、見送ったのはいちばん新しい予定より前の予定
      schedules.some(({ progress }) => progress === "deferred")
        ? "deferred_to_next_day"
        : "estimating",
    )
    .with("deferred", () => "deferred_to_next_day")
    .with("estimating", () => "estimating")
    .with("estimated", () => "estimated")
    .with("no_dishes", () => "no_dishes")
    .with("abandoned", () => "failed")
    .exhaustive();
};
