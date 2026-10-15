import type { WeightChangeDirection } from "./weight-change-direction";

// 体重が、比べる体重と同じか、それより向きの側（減量は軽い側、増量は重い側）にあるか
export const isOnDirectionSide = ({
  direction,
  weightKg,
  comparedWeightKg,
}: {
  direction: WeightChangeDirection;
  weightKg: number;
  comparedWeightKg: number;
}): boolean => (direction === "lose" ? weightKg <= comparedWeightKg : weightKg >= comparedWeightKg);
