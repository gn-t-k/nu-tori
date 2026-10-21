import { kilocaloriesPerKilogram } from "../../../domain/kilocalories-per-kilogram";
import type { ComputedDailyGuide } from "../computed-daily-guide";
import type { DailyGuideGoal } from "../daily-guide-goal";
import { minimumDailyGuideEnergyKcal } from "../minimum-daily-guide-energy-kcal";
import { computeRequiredPace, type RequiredPaceGoal } from "../compute-required-pace";
import { roundToFiftyKcal } from "../round-to-fifty-kcal";
import { floatingPointTolerance } from "../../../domain/floating-point-tolerance";

// 目標を立てた・立て直したときの1日の目安のカロリー。前の週からの変化を抑えるのは見直しだけなので、ここでは抑えない
export const computeDailyGuideEnergy = ({
  expenditureKcal,
  goal,
}: {
  expenditureKcal: number;
  goal: DailyGuideGoal;
}): Pick<ComputedDailyGuide, "energyKcal" | "limitHits"> => {
  const pace = computeRequiredPace(toRequiredPaceGoalAtStart(goal));
  const energyKcal = expenditureKcal + kilocaloriesPerKilogram * pace.kgPerDay;
  const isBelowMinimum = energyKcal < minimumDailyGuideEnergyKcal - floatingPointTolerance;
  return {
    energyKcal: roundToFiftyKcal(Math.max(energyKcal, minimumDailyGuideEnergyKcal)),
    limitHits: [
      ...(pace.isLimited ? (["required_pace"] as const) : []),
      ...(isBelowMinimum ? (["minimum_energy"] as const) : []),
    ],
  };
};

// 立てた・立て直したときは、開始の日の体重の傾向から出す。目標はまだ置き場に無く、向きと日数は案の計算で決まっている（置き場の目標から出すのは toRequiredPaceGoalFromDay）。維持の目標体重は開始の日の体重の傾向（0.1 kg 単位）なので、幅の中にある
const toRequiredPaceGoalAtStart = (goal: DailyGuideGoal): RequiredPaceGoal =>
  goal.direction === "maintain"
    ? { ...goal, weightTrendKg: goal.targetWeightKg }
    : {
        direction: goal.direction,
        goalStartingWeightTrendKg: goal.startingWeightTrendKg,
        targetWeightKg: goal.targetWeightKg,
        weightTrendKg: goal.startingWeightTrendKg,
        daysToDeadline: goal.daysFromStartToDeadline,
      };
