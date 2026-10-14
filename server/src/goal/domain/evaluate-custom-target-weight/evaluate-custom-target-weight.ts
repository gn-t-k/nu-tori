import { computeDailyGuide } from "../../../daily-guide/domain/compute-daily-guide";
import type { ComputedDailyGuide } from "../../../daily-guide/domain/computed-daily-guide";
import { computeDailyGuideDifferenceKcal } from "../../../daily-guide/domain/compute-daily-guide-difference-kcal";
import { computeTargetWeightLimits } from "../compute-target-weight-limits";
import type { CustomTargetWeightRejectionReason } from "../custom-target-weight-rejection-reason";
import type { ProposalPace } from "../proposal-pace";
import { roundToTenthKg } from "../round-to-tenth-kg";
import { weeklyPaceRates } from "../weekly-pace-rates";
import type { WeightChangeDirection } from "../weight-change-direction";
import type { WeightChangeGoalInputs } from "../weight-change-goal-inputs";

// 自分で決めた目標体重を受け付けるかを決め、受け付けるなら1日の目安と大変さを返す
export const evaluateCustomTargetWeight = ({
  targetWeightKg: enteredTargetWeightKg,
  ...goal
}: WeightChangeGoalInputs & { targetWeightKg: number }):
  | {
      status: "accepted";
      // 0.1kg 単位に四捨五入した目標体重。1日の目安と大変さは、この値で計算する
      targetWeightKg: number;
      dailyGuide: ComputedDailyGuide;
      // 1日の目安と推定消費カロリーの差（少ないときは負）
      dailyGuideDifferenceKcal: number;
      difficulty: ProposalPace;
    }
  | {
      status: "rejected";
      reason: CustomTargetWeightRejectionReason;
      // 減量の案を1つも出せないときは、受け付ける目標体重が無い
      nearestAcceptedTargetWeightKg: number | undefined;
    } => {
  const { direction, expenditureKcal, startingWeightTrendKg, daysFromStartToDeadline } = goal;
  const targetWeightKg = roundToTenthKg(enteredTargetWeightKg, "round");
  const { gentlestKg, fastestKg, fastestEndReason } = computeTargetWeightLimits(goal);
  // 向きの側へ進んだ量。減量は軽いほど、増量は重いほど大きい
  const progressOf = (weightKg: number): number => (direction === "lose" ? -weightKg : weightKg);
  const hasAcceptedTargetWeight = progressOf(gentlestKg) <= progressOf(fastestKg);
  if (progressOf(targetWeightKg) < progressOf(gentlestKg)) {
    return {
      status: "rejected",
      reason: "not_on_direction_side",
      nearestAcceptedTargetWeightKg: hasAcceptedTargetWeight ? gentlestKg : undefined,
    };
  }
  if (progressOf(targetWeightKg) > progressOf(fastestKg)) {
    return {
      status: "rejected",
      reason: fastestEndReason,
      nearestAcceptedTargetWeightKg: hasAcceptedTargetWeight ? fastestKg : undefined,
    };
  }
  const dailyGuide = computeDailyGuide({
    expenditureKcal,
    goal: { direction, startingWeightTrendKg, targetWeightKg, daysFromStartToDeadline },
  });
  return {
    status: "accepted",
    targetWeightKg,
    dailyGuide,
    dailyGuideDifferenceKcal: computeDailyGuideDifferenceKcal({
      expenditureKcal,
      dailyGuideEnergyKcal: dailyGuide.energyKcal,
    }),
    difficulty: classifyDifficulty({
      direction,
      weeklyPaceRate:
        (Math.abs(targetWeightKg - startingWeightTrendKg) / daysFromStartToDeadline) *
        (7 / startingWeightTrendKg),
    }),
  };
};

// 必要な速さを案の速さで区切る。ゆるめ以下・標準まで・ハードまで
const classifyDifficulty = ({
  direction,
  weeklyPaceRate,
}: {
  direction: WeightChangeDirection;
  weeklyPaceRate: number;
}): ProposalPace => {
  // 案の目標体重は案の速さちょうどになりうるので、浮動小数の誤差でひとつ上の段階にしない
  const tolerance = 1e-9;
  const { gentle, standard } = weeklyPaceRates[direction];
  if (weeklyPaceRate <= gentle * (1 + tolerance)) {
    return "gentle";
  }
  return weeklyPaceRate <= standard * (1 + tolerance) ? "standard" : "hard";
};
