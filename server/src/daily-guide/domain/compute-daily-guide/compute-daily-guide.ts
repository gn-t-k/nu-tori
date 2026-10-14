import { computeDailyGuideEnergy } from "../compute-daily-guide-energy";
import { computeMacronutrientGuides } from "../compute-macronutrient-guides";
import type { DailyGuideLimitType } from "../daily-guide";
import type { DailyGuideGoal } from "../daily-guide-goal";

// 目標を立てた・立て直したときの1日の目安。開始の日から当てる
export const computeDailyGuide = ({
  expenditureKcal,
  goal,
}: {
  expenditureKcal: number;
  goal: DailyGuideGoal;
}): {
  energyKcal: number;
  proteinG: number;
  fatG: number;
  carbohydrateG: number;
  limitHits: Exclude<DailyGuideLimitType, "weekly_change">[];
} => {
  const { energyKcal, limitHits } = computeDailyGuideEnergy({ expenditureKcal, goal });
  return {
    energyKcal,
    ...computeMacronutrientGuides({ energyKcal, targetWeightKg: goal.targetWeightKg }),
    limitHits,
  };
};
