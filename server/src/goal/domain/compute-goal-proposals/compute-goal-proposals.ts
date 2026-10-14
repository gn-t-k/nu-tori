import { computeDailyGuide } from "../../../daily-guide/domain/compute-daily-guide";
import { computeDailyGuideDifferenceKcal } from "../../../daily-guide/domain/compute-daily-guide-difference-kcal";
import { computeTargetWeightAtPace } from "../compute-target-weight-at-pace";
import { computeTargetWeightLimits } from "../compute-target-weight-limits";
import type { ProposalPace } from "../proposal-pace";
import { weeklyPaceRates } from "../weekly-pace-rates";
import type { WeightChangeDirection } from "../weight-change-direction";

// 目標案の3つの枠を、ゆるい順に返す。案の大変さは、その案の段階（pace）
export const computeGoalProposals = (goal: {
  direction: WeightChangeDirection;
  expenditureKcal: number;
  startingWeightTrendKg: number;
  // 開始の日から期限の日までの日数（両端を含む）
  daysFromStartToDeadline: number;
}): ({ pace: ProposalPace } & (
  | {
      status: "offered";
      targetWeightKg: number;
      dailyGuide: ReturnType<typeof computeDailyGuide>;
      // 1日の目安と推定消費カロリーの差（少ないときは負）
      dailyGuideDifferenceKcal: number;
    }
  // 出せない枠は、1日の目安が下限を下回らないところまで速さを落とした結果でしか出ない
  | { status: "unavailable"; reason: "daily_guide_below_minimum" }
))[] => {
  const { direction, expenditureKcal, startingWeightTrendKg, daysFromStartToDeadline } = goal;
  const { gentlestKg, fastestKg } = computeTargetWeightLimits(goal);
  // 案の速さだと1日の目安が下限を下回るときは、下回らない速さ（受け付けるいちばん速い目標体重）まで落とす
  const candidates = (["gentle", "standard", "hard"] as const).map((pace) => {
    const atPaceKg = computeTargetWeightAtPace({
      direction,
      startingWeightTrendKg,
      weeklyPaceRate: weeklyPaceRates[direction][pace],
      daysFromStartToDeadline,
    });
    return {
      pace,
      targetWeightKg:
        direction === "lose" ? Math.max(atPaceKg, fastestKg) : Math.min(atPaceKg, fastestKg),
    };
  });
  return candidates.map(({ pace, targetWeightKg }, index) => {
    const isOnDirectionSide =
      direction === "lose" ? targetWeightKg <= gentlestKg : targetWeightKg >= gentlestKg;
    const isSameAsGentlerProposal = targetWeightKg === candidates[index - 1]?.targetWeightKg;
    if (!isOnDirectionSide || isSameAsGentlerProposal) {
      return { pace, status: "unavailable", reason: "daily_guide_below_minimum" };
    }
    const dailyGuide = computeDailyGuide({
      expenditureKcal,
      goal: { direction, startingWeightTrendKg, targetWeightKg, daysFromStartToDeadline },
    });
    return {
      pace,
      status: "offered",
      targetWeightKg,
      dailyGuide,
      dailyGuideDifferenceKcal: computeDailyGuideDifferenceKcal({
        expenditureKcal,
        dailyGuideEnergyKcal: dailyGuide.energyKcal,
      }),
    };
  });
};
