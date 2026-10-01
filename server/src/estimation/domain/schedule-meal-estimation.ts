import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import type { Meal } from "../../meal/domain/meal";
import type { MealPhotoStore } from "../../meal/domain/meal-photo-store";
import type { EstimationScheduleStore } from "./estimation-schedule-store";

// 写真がすべて届いた食事を、まだ入れていなければ推定の予定に入れる。入れたら true（推定の状態が変わる）。
// 食事の作る書き込みと写真の要求のどちらでそろっても、同じトランザクションの中で呼ぶ
export const scheduleMealEstimation = (
  stores: { mealPhoto: MealPhotoStore; estimationSchedule: EstimationScheduleStore },
  meal: Pick<Meal, "id" | "sentTimeZone">,
  now: Date,
): boolean => {
  if (
    stores.mealPhoto.hasUnreceivedPhotos(meal.id) ||
    stores.estimationSchedule.hasScheduleOfMeal(meal.id)
  ) {
    return false;
  }
  stores.estimationSchedule.insertMealSchedule({
    id: crypto.randomUUID(),
    dueAt: now,
    countedOn: computeCalendarDayInTimeZone(
      now,
      findLatestValidTimeZone(stores.estimationSchedule) ?? meal.sentTimeZone,
    ),
    mealId: meal.id,
  });
  return true;
};

// 数える日は、受け取った時点のユーザーの最新のタイムゾーンで決める。控えの名前が読めないときは、食事を送ったときのタイムゾーン（確かめ済み）にする
const findLatestValidTimeZone = (store: EstimationScheduleStore): string | undefined => {
  const timeZone = store.findLatestTimeZone();
  return timeZone !== undefined && isTimeZoneName(timeZone) ? timeZone : undefined;
};
