import { findWeightTrendOnOrBefore } from "../../weight-trend/domain/find-weight-trend-on-or-before";
import type { WeightTrend } from "../../weight-trend/domain/weight-trend";
import { classifyGoal } from "./classify-goal";
import { computePace, type Pace } from "./compute-pace";
import type { Goal } from "./goal";

// 置き場の目標の、その日のペース。判定は端末と同じ手順の computePace に、目標を維持か減量・増量に分けて渡す。
// ペースは、目標の開始の日以前に体重の傾向がある目標だけを判定できる（目標を立てたあとに、その前の体重記録を消すと無くなる）
export const computeGoalPace = ({
  goal,
  judgedOn,
  weightTrend,
  weightRecordDays,
}: {
  goal: Pick<
    Goal,
    "startedOn" | "startingWeightTrendKg" | "targetWeightKg" | "weightChange" | "achievement"
  >;
  judgedOn: string;
  weightTrend: WeightTrend;
  // 体重記録のある日（YYYY-MM-DD）
  weightRecordDays: readonly string[];
}): Pace | undefined => {
  if (findWeightTrendOnOrBefore(weightTrend, goal.startedOn) === undefined) {
    return undefined;
  }
  const classified = classifyGoal(goal);
  return computePace({
    judgedOn,
    weightTrend,
    weightRecordDays,
    goal:
      classified.direction === "maintain"
        ? { direction: "maintain", targetWeightKg: goal.targetWeightKg }
        : {
            direction: classified.direction,
            startedOn: goal.startedOn,
            deadlineOn: classified.weightChange.deadlineOn,
            targetWeightKg: goal.targetWeightKg,
          },
    achievedOn: goal.achievement?.achievedOn,
  });
};
