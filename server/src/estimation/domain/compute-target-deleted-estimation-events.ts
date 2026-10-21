import { findOngoingEstimationIds } from "../../dish-estimation-status/domain/dish-estimation-schedule";
import type { UsageEvent } from "../../domain/usage-event";
import { computeEstimationEndedEvent } from "./compute-estimation-ended-event";
import type { EstimationTarget } from "./estimation-target";

// 推定中に対象の食事・料理が消えるときの、推定中の推定ごとの出来事（消えたものの区分で送る）。
// 推定の書き込みの complete・abandon と違い、終えたことを行に書かない: 対象を消すとつなぎが CASCADE で消え、届いた推定は捨てられる。
// 消したあとは推定から対象を辿れないので、消す書き込みを決めるとき（commit の前）に読む
export const computeTargetDeletedEstimationEvents = (
  stores: EstimationEndedEventStores,
  target: EstimationTarget,
  finalStatus: "meal_deleted" | "dish_deleted",
  deletedAt: Date,
): UsageEvent[] =>
  findOngoingEstimationIdsOfTarget(stores, target).map((estimationId) =>
    computeEstimationEndedEvent(stores, {
      estimationId,
      target,
      finalStatus,
      endedAt: deletedAt,
      dishCount: 0,
      ingredients: [],
    }),
  );

const findOngoingEstimationIdsOfTarget = (
  stores: EstimationEndedEventStores,
  target: EstimationTarget,
): string[] => {
  if (target.type === "dish") {
    return findOngoingEstimationIds(stores.dishEstimationStatus.findSchedulesOfDish(target.dishId));
  }
  const estimationId = stores.estimation.findOngoingEstimationIdOfMeal(target.mealId);
  return estimationId === undefined ? [] : [estimationId];
};

type EstimationEndedEventStores = Parameters<typeof computeEstimationEndedEvent>[0];
