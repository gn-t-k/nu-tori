import { roundToTenthKg } from "./round-to-tenth-kg";
import type { WeightChangeDirection } from "./weight-change-direction";

// その速さで期限まで進んだときの目標体重。0.1kg 単位で、開始の日の体重の傾向の側へ丸める
export const computeTargetWeightAtPace = ({
  direction,
  startingWeightTrendKg,
  weeklyPaceRate,
  daysFromStartToDeadline,
}: {
  direction: WeightChangeDirection;
  startingWeightTrendKg: number;
  weeklyPaceRate: number;
  daysFromStartToDeadline: number;
}): number => {
  const changeRate = (weeklyPaceRate * daysFromStartToDeadline) / 7;
  return direction === "lose"
    ? roundToTenthKg(startingWeightTrendKg * (1 - changeRate), "ceil")
    : roundToTenthKg(startingWeightTrendKg * (1 + changeRate), "floor");
};
