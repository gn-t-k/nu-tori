import { kilocaloriesPerKilogram } from "../../../domain/kilocalories-per-kilogram";
import { weeklyPaceRates } from "../../../goal/domain/weekly-pace-rates";
import type { ComputedDailyGuide } from "../computed-daily-guide";
import type { DailyGuideGoal } from "../daily-guide-goal";
import { minimumDailyGuideEnergyKcal } from "../minimum-daily-guide-energy-kcal";

// 目標を立てた・立て直したときの1日の目安のカロリー。前の週からの変化を抑えるのは見直しだけなので、ここでは抑えない
export const computeDailyGuideEnergy = ({
  expenditureKcal,
  goal,
}: {
  expenditureKcal: number;
  goal: DailyGuideGoal;
}): Pick<ComputedDailyGuide, "energyKcal" | "limitHits"> => {
  const pace = computeLimitedPace(goal);
  const energyKcal = expenditureKcal + kilocaloriesPerKilogram * pace.kgPerDay;
  const isBelowMinimum = energyKcal < minimumDailyGuideEnergyKcal - tolerance;
  return {
    energyKcal: roundToFiftyKcal(Math.max(energyKcal, minimumDailyGuideEnergyKcal)),
    limitHits: [
      ...(pace.isLimited ? (["required_pace"] as const) : []),
      ...(isBelowMinimum ? (["minimum_energy"] as const) : []),
    ],
  };
};

// 必要な速さ（kg/日。減量は負）を、目標の向きと逆にせず、ハード案の速さまでに抑える
const computeLimitedPace = (goal: DailyGuideGoal): { kgPerDay: number; isLimited: boolean } => {
  if (goal.direction === "maintain") {
    return { kgPerDay: 0, isLimited: false };
  }
  // 期限まで7日に満たないときは7日で割り、残りの日数で速さが跳ね上がらないようにする
  const days = Math.max(goal.daysFromStartToDeadline, 7);
  const sign = goal.direction === "lose" ? -1 : 1;
  const towardGoalKgPerDay = Math.max(
    (sign * (goal.targetWeightKg - goal.startingWeightTrendKg)) / days,
    0,
  );
  const maximumKgPerDay = (weeklyPaceRates[goal.direction].hard * goal.startingWeightTrendKg) / 7;
  // ハード案の目標体重は上限ちょうどの速さになるので、浮動小数の誤差で上限に当たったことにしない
  const isLimited = towardGoalKgPerDay > maximumKgPerDay * (1 + tolerance);
  return { kgPerDay: sign * Math.min(towardGoalKgPerDay, maximumKgPerDay), isLimited };
};

const roundToFiftyKcal = (energyKcal: number): number =>
  Math.round(energyKcal / 50 + tolerance) * 50;

const tolerance = 1e-9;
