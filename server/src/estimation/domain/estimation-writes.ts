import type { UsageEvent } from "../../domain/usage-event";
import type { Ingredient } from "../../ingredient/domain/ingredient";
import type { EstimationEvents } from "./estimation-events";
import type { EstimationTarget } from "./estimation-target";

// 推定の書き込み。推定の書き込みの口（writeEstimationEvents）が、書く関数にだけ渡す。
// 推定の状態を変え得る書き込みは対象の食事か料理を受け取り、口はその記録の状態を書く前とあとで比べる
export type EstimationWrites = {
  scheduleMeal: (schedule: EstimationEvents["schedule"]) => void;
  scheduleDish: (schedule: EstimationEvents["dishSchedule"]) => void;
  // 1日の上限で見送るときは、次の日の予定も同じ書き込みで、同じ対象に足す
  deferToNextDay: (
    deferral: EstimationEvents["deferral"] & {
      target: EstimationTarget;
      nextSchedule: { id: string; dueAt: Date; countedOn: string };
    },
  ) => void;
  beginEstimation: (
    estimation: EstimationEvents["estimation"] & { target: EstimationTarget },
  ) => void;
  // 試みとその結果は、推定の状態を変えない
  beginAttempt: (attempt: EstimationEvents["attempt"]) => void;
  recordAttemptResult: (attemptResult: EstimationEvents["attemptResult"]) => void;
  // 推定を終える書き込みは、PostHog に送る推定ごとの出来事（estimation_ended）を返す。きっかけと試みは口が読む。
  // 料理が見つからなければ（dishCount が 0）料理なしで、ほかは推定できたで完了する。ingredients は出来事で数える材料
  complete: (
    completion: Omit<EstimationEvents["completion"], "result"> & {
      target: EstimationTarget;
      dishCount: number;
      ingredients: readonly Pick<Ingredient, "nutrientSource">[];
    },
  ) => UsageEvent;
  abandon: (
    abandonment: EstimationEvents["abandonment"] & { target: EstimationTarget },
  ) => UsageEvent;
  // 1つの推定が時刻を決めるのは、その推定の予定のつなぎの食事だけ（#419 の設計判断 40）。食事は受け取らず、推定から辿る。
  // 時刻は推定の状態を変えない
  estimateMealEatenAt: (estimation: EstimationEvents["mealEatenAtEstimation"]) => void;
  // 食事は先に書いておく。推定の状態（推定が完了していれば推定できた）が変わるので、変更を足す
  recordCreatedMeal: (createdMeal: EstimationEvents["createdMeal"]) => void;
};
