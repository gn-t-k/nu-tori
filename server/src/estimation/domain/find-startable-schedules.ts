import { findReceivedAtOfSchedule } from "../../dish-estimation-status/domain/dish-estimation-schedule";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import type { MealPhotoStore } from "../../meal/domain/meal-photo-store";
import type { EstimationScheduleStore, WaitingSchedule } from "./estimation-schedule-store";

type Stores = {
  estimationSchedule: EstimationScheduleStore;
  mealPhoto: MealPhotoStore;
  dishEstimationStatus: DishEstimationStatusStore;
};

// 料理が対象の予定が、食事の写真を待つ長さ（#332 の「写真を待つ」）。書き込みが届いていれば端末はつながっていて、
// 写真もふつうは数分で届くので、名前を直した・料理を足した書き込みを受け取ってから1時間届かなければ、写真は失われたと見る
export const photoWaitLimitMs = 3_600_000;

// 待っている予定のうち、いま推定を始められるもの（早い順）。料理が対象の予定は、食事の写真がまだすべては届いていないあいだ、
// 写真を待つ時間を過ぎるまで待たせる（推定も見送りもせず、数えない）
export const findStartableSchedules = (stores: Stores, now: Date): WaitingSchedule[] =>
  stores.estimationSchedule
    .findWaitingSchedules(now)
    .filter((schedule) => computeStartsAt(stores, schedule).getTime() <= now.getTime());

// 待っている予定のうち、推定を始められるいちばん早い時刻。アラームの時刻に使う。写真を待たせている予定は、写真を待つ時間を過ぎる時刻。
// 写真が届いたら、写真の要求の入口で張り直すので、届いた時点で始められる
export const findEarliestScheduleStartsAt = (stores: Stores): Date | undefined =>
  stores.estimationSchedule
    .findWaitingSchedules(undefined)
    .map((schedule) => computeStartsAt(stores, schedule))
    .toSorted((a, b) => a.getTime() - b.getTime())[0];

// 待つ時間は、予定のもとの書き込みを受け取った時刻から数える（見送りから作る次の日の予定でも延ばさない）
const computeStartsAt = (stores: Stores, { scheduleId, target, dueAt }: WaitingSchedule): Date => {
  if (target.type === "meal" || !stores.mealPhoto.hasUnreceivedPhotos(target.mealId)) {
    return dueAt;
  }
  const receivedAt = findReceivedAtOfSchedule(
    stores.dishEstimationStatus.findSchedulesOfDish(target.dishId),
    scheduleId,
  );
  return new Date(Math.max(dueAt.getTime(), receivedAt.getTime() + photoWaitLimitMs));
};
