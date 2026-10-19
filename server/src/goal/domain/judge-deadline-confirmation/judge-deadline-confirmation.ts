import { findStartingWeightTrend } from "../../../weight-trend/domain/find-starting-weight-trend";
import type { WeightTrend } from "../../../weight-trend/domain/weight-trend";
import type { Goal } from "../goal";

export type DeadlineConfirmationGoal = Pick<
  Goal,
  "weightChange" | "deadlineConfirmation" | "closure"
>;

// 期限の日の結果を確定するか。期限の日が終わって最初の要求（要求のタイムゾーンで期限の日の翌日以降）で、
// 閉じていない目標と、期限の日以降に閉じた目標（期限の日に立て直した目標を含む）の、期限の日の体重の傾向を確定する。
// 体重の傾向は最後の体重記録の日で終わるので、期限の日以前で最も新しい値を使う。
// 確定のあとは確定し直さない（遅れて届いた体重でも変えない）。確定しないときは undefined
export const judgeDeadlineConfirmation = ({
  goal,
  today,
  weightTrend,
}: {
  goal: DeadlineConfirmationGoal;
  // 要求のタイムゾーンでの今日
  today: string;
  weightTrend: WeightTrend;
}): { deadlineWeightTrendKg: number } | undefined => {
  if (goal.weightChange === undefined || goal.deadlineConfirmation !== undefined) {
    return undefined;
  }
  const { deadlineOn } = goal.weightChange;
  if (today <= deadlineOn || (goal.closure !== undefined && goal.closure.endedOn < deadlineOn)) {
    return undefined;
  }
  const deadlineTrend = findStartingWeightTrend(weightTrend, deadlineOn);
  return deadlineTrend === undefined ? undefined : { deadlineWeightTrendKg: deadlineTrend.trendKg };
};
