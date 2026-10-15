import { minimumDailyGuideEnergyKcal } from "../../daily-guide/domain/minimum-daily-guide-energy-kcal";
import { computeTargetWeightAtPace } from "./compute-target-weight-at-pace";
import { kilocaloriesPerKilogram } from "../../domain/kilocalories-per-kilogram";
import { roundToTenthKg } from "./round-to-tenth-kg";
import { weeklyPaceRates } from "./weekly-pace-rates";
import type { FastestEndReason } from "./fastest-end-reason";
import type { WeightChangeGoalInputs } from "./weight-change-goal-inputs";
import { isOnDirectionSide } from "./is-on-direction-side";
import type { WeightChangeDirection } from "./weight-change-direction";

// 受け付ける目標体重の両端（0.1kg 単位）。いちばん速い端が、いちばんゆるい端より体重の傾向の側にあるときは、受け付ける目標体重が無い
export const computeTargetWeightLimits = ({
  direction,
  expenditureKcal,
  startingWeightTrendKg,
  daysFromStartToDeadline,
}: WeightChangeGoalInputs): {
  gentlestKg: number;
  fastestKg: number;
  fastestEndReason: FastestEndReason;
} => {
  // 画面は体重の傾向を 0.1kg 単位で出すので、0.1kg に丸めた体重の傾向と同じ目標体重は、向きの側に出ていないとみなす
  const startingTenths = Math.round(startingWeightTrendKg * 10);
  const hardPaceKg = computeTargetWeightAtPace({
    direction,
    startingWeightTrendKg,
    weeklyPaceRate: weeklyPaceRates[direction].hard,
    daysFromStartToDeadline,
  });
  // 下限 1,200 kcal は食べる量を減らす減量にだけかかる
  if (direction === "gain") {
    return {
      gentlestKg: (startingTenths + 1) / 10,
      fastestKg: hardPaceKg,
      fastestEndReason: "pace_too_fast",
    };
  }
  const minimumEnergyKg = roundToTenthKg(
    startingWeightTrendKg -
      ((expenditureKcal - minimumDailyGuideEnergyKcal) / kilocaloriesPerKilogram) *
        daysFromStartToDeadline,
    "ceil",
  );
  return {
    gentlestKg: (startingTenths - 1) / 10,
    fastestKg: Math.max(hardPaceKg, minimumEnergyKg),
    fastestEndReason: minimumEnergyKg > hardPaceKg ? "daily_guide_below_minimum" : "pace_too_fast",
  };
};

// 受け付ける目標体重があるか。いちばん速い端が、いちばんゆるい端と同じか、それより向きの側にあるとき
export const hasAcceptedTargetWeight = (
  direction: WeightChangeDirection,
  { gentlestKg, fastestKg }: { gentlestKg: number; fastestKg: number },
): boolean => isOnDirectionSide({ direction, weightKg: fastestKg, comparedWeightKg: gentlestKg });
