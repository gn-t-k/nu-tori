import type { RecordId } from "../../domain/record-id";
import type { EstimationScheduleStore } from "./estimation-schedule-store";

// 推定を始めた食事を受け取った時刻（いちばん早い予定の時刻）。推定は予定から始めるので、つなぎのある食事には必ずある
export const findMealReceivedAt = (store: EstimationScheduleStore, mealId: RecordId): Date => {
  const receivedAt = store.findEarliestDueAtOfMeal(mealId);
  if (receivedAt === undefined) {
    throw new Error(`推定を始めた食事に予定が無い: ${mealId}`);
  }
  return receivedAt;
};
