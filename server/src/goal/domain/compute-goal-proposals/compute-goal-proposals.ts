import { computeDailyGuide } from "../../../daily-guide/domain/compute-daily-guide";
import type { ComputedDailyGuide } from "../../../daily-guide/domain/computed-daily-guide";
import { computeDailyGuideDifferenceKcal } from "../../../daily-guide/domain/compute-daily-guide-difference-kcal";
import { computeTargetWeightAtPace } from "../compute-target-weight-at-pace";
import { computeTargetWeightLimits } from "../compute-target-weight-limits";
import { isOnDirectionSide } from "../is-on-direction-side";
import { type ProposalPace, proposalPaces } from "../proposal-pace";
import { weeklyPaceRates } from "../weekly-pace-rates";
import type { WeightChangeGoalInputs } from "../weight-change-goal-inputs";

// 目標案の3つの枠を、ゆるい順に返す。案の大変さは、その案の段階（pace）
export const computeGoalProposals = (
  goal: WeightChangeGoalInputs,
): {
  proposals: GoalProposal[];
  // 1日の目安が下限を下回らないよう、速さを落とした案があったか
  hadSlowedProposal: boolean;
} => {
  const { direction, expenditureKcal, startingWeightTrendKg, daysFromStartToDeadline } = goal;
  const { gentlestKg, fastestKg, fastestEndReason } = computeTargetWeightLimits(goal);
  // 案の速さだと1日の目安が下限を下回るときは、下回らない速さ（受け付けるいちばん速い目標体重）まで落とす
  const candidates = proposalPaces.map((pace) => {
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
  const proposals = candidates.map(({ pace, targetWeightKg }, index): GoalProposal => {
    const isSameAsGentlerProposal = targetWeightKg === candidates[index - 1]?.targetWeightKg;
    if (
      !isOnDirectionSide({ direction, weightKg: targetWeightKg, comparedWeightKg: gentlestKg }) ||
      isSameAsGentlerProposal
    ) {
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
  // 速さを落とすのは、いちばん速い端（ハード案の側）が下限で決まっているときだけ
  return { proposals, hadSlowedProposal: fastestEndReason === "daily_guide_below_minimum" };
};

// 目標案の1つの枠
export type GoalProposal = { pace: ProposalPace } & (
  | {
      status: "offered";
      targetWeightKg: number;
      dailyGuide: ComputedDailyGuide;
      // 1日の目安と推定消費カロリーの差（少ないときは負）
      dailyGuideDifferenceKcal: number;
    }
  // 出せない枠は、1日の目安が下限を下回らないところまで速さを落とした結果でしか出ない
  | { status: "unavailable"; reason: "daily_guide_below_minimum" }
);
