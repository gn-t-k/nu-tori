import { findReceivedAtOfSchedule } from "../../dish-estimation-status/domain/dish-estimation-schedule";
import type { WaitingSchedule } from "./estimation-schedule-store";
import type { ScheduleStartStores } from "./schedule-start-stores";

// 待っている予定を始められる時刻。待つ時間は、予定のもとの書き込みを受け取った時刻から数える（見送りから作る次の日の予定でも延ばさない）
export const computeScheduleStartsAt = (
  stores: ScheduleStartStores,
  { scheduleId, target, dueAt }: WaitingSchedule,
): Date => {
  if (target.type === "meal" || !stores.mealPhoto.hasUnreceivedPhotos(target.mealId)) {
    return dueAt;
  }
  const receivedAt = findReceivedAtOfSchedule(
    stores.dishEstimationStatus.findSchedulesOfDish(target.dishId),
    scheduleId,
  );
  return new Date(Math.max(dueAt.getTime(), receivedAt.getTime() + photoWaitLimitMs));
};

// 料理が対象の予定が、食事の写真を待つ長さ（#332 の「写真を待つ」）。書き込みが届いていれば端末はつながっていて、
// 写真もふつうは数分で届くので、名前を直した・料理を足した書き込みを受け取ってから1時間届かなければ、写真は失われたと見る
const photoWaitLimitMs = 3_600_000;
