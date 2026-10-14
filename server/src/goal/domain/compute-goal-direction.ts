import type { Goal } from "./goal";
import type { GoalDirection } from "./goal-direction";

// 目標の向き。減量・増量の行が無ければ維持、あれば目標体重が開始の日の体重の傾向より小さいとき減量、ほかは増量（#523 の設計判断 30）。
// 減量・増量で2つの体重が等しい目標は、書く口が作らない
export const computeGoalDirection = (
  goal: Pick<Goal, "startingWeightTrendKg" | "targetWeightKg" | "weightChange">,
): GoalDirection => {
  if (goal.weightChange === undefined) {
    return "maintain";
  }
  return goal.targetWeightKg < goal.startingWeightTrendKg ? "lose" : "gain";
};
