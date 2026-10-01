import type { RecordKindStores } from "./record-kind-stores";

// Durable Object のアラームは一度に1つなので、次のうちいちばん早い時刻に合わせる。どれも無ければ undefined。
// 1. 待っている推定の予定の時刻 2. 写真の控えの消し残し（今すぐ）
export const computeNextAlarmAt = (
  stores: Pick<RecordKindStores, "mealPhoto" | "estimationSchedule">,
  now: Date,
): Date | undefined => {
  const candidates = [
    stores.estimationSchedule.findEarliestWaitingDueAt(),
    stores.mealPhoto.findLeftoverPhotoIds().length > 0 ? now : undefined,
  ].filter((candidate) => candidate !== undefined);
  return candidates.toSorted((a, b) => a.getTime() - b.getTime())[0];
};
