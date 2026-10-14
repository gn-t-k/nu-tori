import { computeTargetWeightLimits } from "../compute-target-weight-limits";
import type { FastestEndReason } from "../fastest-end-reason";
import type { WeightChangeGoalInputs } from "../weight-change-goal-inputs";

// 自分で決める目標体重の受け付ける幅（0.1kg 単位、両端を含む）。受け付ける目標体重が1つも無いときは、幅が無い
export const computeAcceptedTargetWeightRange = (
  goal: WeightChangeGoalInputs,
):
  | {
      minimumKg: number;
      maximumKg: number;
      // いちばん速い端（減量は下の端、増量は上の端）を決めた理由
      fastestEndReason: FastestEndReason;
    }
  | undefined => {
  const { gentlestKg, fastestKg, fastestEndReason } = computeTargetWeightLimits(goal);
  const minimumKg = Math.min(gentlestKg, fastestKg);
  const maximumKg = Math.max(gentlestKg, fastestKg);
  const isFastestOnDirectionSide =
    goal.direction === "lose" ? fastestKg <= gentlestKg : fastestKg >= gentlestKg;
  return isFastestOnDirectionSide ? { minimumKg, maximumKg, fastestEndReason } : undefined;
};
