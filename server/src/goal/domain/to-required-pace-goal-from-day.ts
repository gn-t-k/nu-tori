import type { RequiredPaceGoal } from "../../daily-guide/domain/compute-required-pace";
import { countDaysInclusive } from "./accepted-deadline/count-days-inclusive";
import { classifyGoal } from "./classify-goal";
import type { Goal } from "./goal";

// 置き場の目標で、新しい1日の目安を当てる最初の日 firstDay から出す必要な速さの元。
// 体重の傾向はその時点の値（見直しでは firstDay の前の日曜の値）、日数は firstDay から期限の日まで。上限は目標の開始の日の体重の傾向から出す
export const toRequiredPaceGoalFromDay = (
  goal: Pick<Goal, "startingWeightTrendKg" | "targetWeightKg" | "weightChange">,
  { firstDay, weightTrendKg }: { firstDay: string; weightTrendKg: number },
): RequiredPaceGoal => {
  const classified = classifyGoal(goal);
  if (classified.direction === "maintain") {
    return { direction: "maintain", targetWeightKg: goal.targetWeightKg, weightTrendKg };
  }
  return {
    direction: classified.direction,
    goalStartingWeightTrendKg: goal.startingWeightTrendKg,
    targetWeightKg: goal.targetWeightKg,
    weightTrendKg,
    daysToDeadline: countDaysInclusive(firstDay, classified.weightChange.deadlineOn),
  };
};
