import type { Goal, GoalWeightChange } from "./goal";
import type { WeightChangeDirection } from "./weight-change-direction";

// 目標を、維持か、期限を持つ減量・増量かに分ける。減量・増量の行が無ければ維持、
// あれば目標体重が開始の日の体重の傾向より小さいとき減量、ほかは増量（#523 の設計判断 30）。
// 減量・増量で2つの体重が等しい目標は、書く口が作らない
export const classifyGoal = (
  goal: Pick<Goal, "startingWeightTrendKg" | "targetWeightKg" | "weightChange">,
):
  | { direction: "maintain" }
  | { direction: WeightChangeDirection; weightChange: GoalWeightChange } => {
  if (goal.weightChange === undefined) {
    return { direction: "maintain" };
  }
  return {
    direction: goal.targetWeightKg < goal.startingWeightTrendKg ? "lose" : "gain",
    weightChange: goal.weightChange,
  };
};
