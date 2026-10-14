import { computeTargetWeightLimits } from "../compute-target-weight-limits";
import type { WeightChangeDirection } from "../weight-change-direction";

// 自分で決める目標体重の受け付ける幅（0.1kg 単位、両端を含む）。受け付ける目標体重が1つも無いときは、幅が無い
export const computeAcceptedTargetWeightRange = (goal: {
  direction: WeightChangeDirection;
  expenditureKcal: number;
  startingWeightTrendKg: number;
  // 開始の日から期限の日までの日数（両端を含む）
  daysFromStartToDeadline: number;
}):
  | {
      minimumKg: number;
      maximumKg: number;
      // いちばん速い端（減量は下の端、増量は上の端）を決めた理由
      fastestEndReason: "pace_too_fast" | "daily_guide_below_minimum";
    }
  | undefined => {
  const { gentlestKg, fastestKg, fastestEndReason } = computeTargetWeightLimits(goal);
  const minimumKg = Math.min(gentlestKg, fastestKg);
  const maximumKg = Math.max(gentlestKg, fastestKg);
  const isFastestOnDirectionSide =
    goal.direction === "loss" ? fastestKg <= gentlestKg : fastestKg >= gentlestKg;
  return isFastestOnDirectionSide ? { minimumKg, maximumKg, fastestEndReason } : undefined;
};
