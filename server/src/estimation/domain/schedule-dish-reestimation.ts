import { findWaitingSchedules } from "../../dish-estimation-status/domain/dish-estimation-schedule";
import type { DishEstimationStatusStore } from "../../dish-estimation-status/domain/dish-estimation-status-store";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { findLatestValidTimeZone } from "../../domain/find-latest-valid-time-zone";
import type { LatestTimeZoneStore } from "../../domain/latest-time-zone-store";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { EstimationWrites } from "./estimation-writes";

// 名前を直した・料理を足した書き込みを当てたときに、料理の推定し直しを予定に入れる（#332 の「推定し直し」）。推定の書き込みの口の中で呼ぶ。
// 同じ料理の、まだ始まっていない前の予定（推定も見送りも無い予定と、見送ったあとの次の日の予定）を、この書き込みの控えで取り消し、
// 書き込みを受け取った時刻の予定を足す。数える日は、受け取った時点のユーザーの最新のタイムゾーン（読めなければ食事を送ったときのもの）での日。
// 始まっている推定は止めない（終わったときに、より新しい予定があるので当てない）
export const scheduleDishReestimation = (
  stores: { dishEstimationStatus: DishEstimationStatusStore; latestTimeZone: LatestTimeZoneStore },
  writes: EstimationWrites,
  dish: { id: string; mealSentTimeZone: string },
  receiptId: WriteReceiptId,
  receivedAt: Date,
): void => {
  for (const { scheduleId } of findWaitingSchedules(
    stores.dishEstimationStatus.findSchedulesOfDish(dish.id),
  )) {
    writes.cancelDishSchedule({ scheduleId, dishId: dish.id, receiptId });
  }
  writes.scheduleDish({
    id: crypto.randomUUID(),
    dishId: dish.id,
    dueAt: receivedAt,
    countedOn: computeCalendarDayInTimeZone(
      receivedAt,
      findLatestValidTimeZone(stores.latestTimeZone) ?? dish.mealSentTimeZone,
    ),
  });
};
