import type { RecordId } from "../../domain/record-id";
import { sortSchedulesNewestFirst } from "../../estimation/domain/sort-schedules-newest-first";
import type { EstimationEvents } from "../../estimation/domain/estimation-events";
import type { EstimationStore } from "../../estimation/domain/estimation-store";
import type { MealEstimationStatusStore } from "./meal-estimation-status-store";

// 食事の推定の状態を決める予定（いちばん新しい予定）の推定の、終わった試みのうち最後のものの結果。
// 推定の状態が「推定できなかった」で終わった理由を、確かめのジョブが知らせるために読む。
// 予定から推定を始めていないか、終わった試みが無ければ undefined
export const findLastEstimationAttemptConclusionOfMeal = (
  stores: { mealEstimationStatus: MealEstimationStatusStore; estimation: EstimationStore },
  mealId: RecordId,
): EstimationEvents["attemptResult"]["conclusion"] | undefined => {
  const latest = sortSchedulesNewestFirst(
    stores.mealEstimationStatus.findSchedulesOfMeal(mealId),
  )[0];
  if (latest === undefined || !("estimationId" in latest)) {
    return undefined;
  }
  return stores.estimation
    .findAttempts(latest.estimationId)
    .flatMap(({ ended }) => (ended === undefined ? [] : [ended.conclusion]))
    .at(-1);
};
