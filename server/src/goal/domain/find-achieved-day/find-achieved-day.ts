import type { WeightTrend } from "../../../weight-trend/domain/weight-trend";
import { computeGoalDirection } from "../compute-goal-direction";
import type { Goal } from "../goal";

export type AchievementGoal = Pick<
  Goal,
  | "startedOn"
  | "startingWeightTrendKg"
  | "targetWeightKg"
  | "weightChange"
  | "achievement"
  | "deadlineConfirmation"
  | "closure"
>;

// 減量・増量の目標の達成した日。開始の日から、目標が閉じる日の前の日までの日で、
// 減量では体重の傾向が目標体重以下、増量では以上になった最初の日。幅は付けない。
// 期限の日の結果を確定したあとは、期限の日より後の日だけを探す（確定のあとに遅れて届いた体重で達成にしない）。
// 一度達成した日は取り消さず、そのまま返す。維持の目標と、まだ届いていない目標には無い
export const findAchievedDay = ({
  goal,
  weightTrend,
}: {
  goal: AchievementGoal;
  weightTrend: WeightTrend;
}): string | undefined => {
  if (goal.achievement !== undefined) {
    return goal.achievement.achievedOn;
  }
  const direction = computeGoalDirection(goal);
  if (direction === "maintain" || goal.weightChange === undefined) {
    return undefined;
  }
  const { deadlineOn } = goal.weightChange;
  const isSearched = (calendarDay: string) =>
    goal.startedOn <= calendarDay &&
    (goal.closure === undefined || calendarDay < goal.closure.endedOn) &&
    (goal.deadlineConfirmation === undefined || deadlineOn < calendarDay);
  return weightTrend.find(
    ({ calendarDay, trendKg }) =>
      isSearched(calendarDay) &&
      (direction === "lose" ? trendKg <= goal.targetWeightKg : trendKg >= goal.targetWeightKg),
  )?.calendarDay;
};
