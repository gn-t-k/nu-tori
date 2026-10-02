import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import type { Meal } from "../../meal/domain/meal";
import type { MealPhotoStore } from "../../meal/domain/meal-photo-store";
import type { EstimationScheduleStore } from "./estimation-schedule-store";
import type { EstimationWrites } from "./estimation-writes";
import { findLatestValidTimeZone } from "./find-latest-valid-time-zone";

// 写真がすべて届いた食事を、まだ入れていなければ推定の予定に入れる。
// 食事の作る書き込みと写真の要求のどちらでそろっても、推定の書き込みの口の中で呼ぶ
export const scheduleMealEstimation = (
  stores: { mealPhoto: MealPhotoStore; estimationSchedule: EstimationScheduleStore },
  writes: EstimationWrites,
  meal: Pick<Meal, "id" | "sentTimeZone">,
  now: Date,
): void => {
  if (
    stores.mealPhoto.hasUnreceivedPhotos(meal.id) ||
    stores.estimationSchedule.hasScheduleOfMeal(meal.id)
  ) {
    return;
  }
  writes.scheduleMeal({
    id: crypto.randomUUID(),
    mealId: meal.id,
    dueAt: now,
    countedOn: computeCalendarDayInTimeZone(
      now,
      findLatestValidTimeZone(stores.estimationSchedule) ?? meal.sentTimeZone,
    ),
  });
};
