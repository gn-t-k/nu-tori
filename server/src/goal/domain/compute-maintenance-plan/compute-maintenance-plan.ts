import { computeDailyGuide } from "../../../daily-guide/domain/compute-daily-guide";
import { roundToTenthKg } from "../round-to-tenth-kg";

// 維持は目標案を出さず、開始の日の体重の傾向（0.1kg 単位）を保つ目標にする。期限は無い
export const computeMaintenancePlan = ({
  expenditureKcal,
  startingWeightTrendKg,
}: {
  expenditureKcal: number;
  startingWeightTrendKg: number;
}): { targetWeightKg: number; dailyGuide: ReturnType<typeof computeDailyGuide> } => {
  const targetWeightKg = roundToTenthKg(startingWeightTrendKg, "round");
  return {
    targetWeightKg,
    dailyGuide: computeDailyGuide({
      expenditureKcal,
      goal: { direction: "maintenance", targetWeightKg },
    }),
  };
};
