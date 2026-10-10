import { computeNextAlarmAtExceptLeftoverPhotos } from "./compute-next-alarm-at-except-leftover-photos";
import type { RecordKindStores } from "./record-kind-stores";

// Durable Object のアラームは一度に1つなので、いちばん早い時刻に合わせる。どれも無ければ undefined。
// 写真の控えの消し残しがあれば今すぐ、無ければ読み分け待ちの文章と、推定の予定と試みのいちばん早い時刻
export const computeNextAlarmAt = (
  stores: Pick<RecordKindStores, "mealPhoto" | "sentText" | "estimationSchedule" | "estimation">,
  now: Date,
): Date | undefined =>
  stores.mealPhoto.findLeftoverPhotoIds().length > 0
    ? now
    : computeNextAlarmAtExceptLeftoverPhotos(stores);
