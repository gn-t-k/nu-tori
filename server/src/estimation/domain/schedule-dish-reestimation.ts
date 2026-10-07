import { generateRecordId, type RecordId } from "../../domain/record-id";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { findLatestValidTimeZone } from "../../domain/find-latest-valid-time-zone";
import type { LatestTimeZoneStore } from "../../domain/latest-time-zone-store";
import type { EstimationWrites } from "./estimation-writes";

// 名前を直した・料理を足した書き込みを当てたときに、料理の推定し直しを予定に入れる（#332 の「推定し直し」）。推定の書き込みの口の中で呼ぶ。
// 書き込みを受け取った時刻の予定を足す。数える日は、受け取った時点のユーザーの最新のタイムゾーン（読めなければ食事を送ったときのもの）での日。
// 推定し直しを待っている料理の名前は直せない（awaiting_estimation で断る）ので、前の予定は待っていない
export const scheduleDishReestimation = (
  stores: { latestTimeZone: LatestTimeZoneStore },
  writes: EstimationWrites,
  dish: { id: RecordId; mealSentTimeZone: string },
  receivedAt: Date,
): void => {
  writes.scheduleDish({
    id: generateRecordId(),
    dishId: dish.id,
    dueAt: receivedAt,
    countedOn: computeCalendarDayInTimeZone(
      receivedAt,
      findLatestValidTimeZone(stores.latestTimeZone) ?? dish.mealSentTimeZone,
    ),
  });
};
