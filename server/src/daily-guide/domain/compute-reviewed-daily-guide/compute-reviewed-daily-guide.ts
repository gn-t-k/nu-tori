import { kilocaloriesPerKilogram } from "../../../domain/kilocalories-per-kilogram";
import { computeMacronutrientGuides } from "../compute-macronutrient-guides";
import type { ComputedReviewedDailyGuide } from "../computed-daily-guide";
import type { DailyGuideMainReason } from "../daily-guide";
import { minimumDailyGuideEnergyKcal } from "../minimum-daily-guide-energy-kcal";
import { computeRequiredPace, type RequiredPaceGoal } from "../compute-required-pace";
import { roundToFiftyKcal } from "../round-to-fifty-kcal";
import { floatingPointTolerance } from "../../../domain/floating-point-tolerance";

// 見直せた週の1日の目安。目標を立てたときと同じ式を、新しい推定消費カロリーと、
// 見直す月曜 M の前の日曜の体重の傾向と M から期限の日までの日数で出し、前の週の1日の目安からの変化を ±150 kcal までに抑える
export const computeReviewedDailyGuide = ({
  expenditureKcal,
  previous,
  goal,
}: {
  // 新しい推定消費カロリー
  expenditureKcal: number;
  // 前の週の1日の目安と、それが使った推定消費カロリー
  previous: { energyKcal: number; expenditureKcal: number };
  goal: RequiredPaceGoal;
}): ComputedReviewedDailyGuide => {
  const pace = computeRequiredPace(goal);
  const formulaKcal = expenditureKcal + kilocaloriesPerKilogram * pace.kgPerDay;
  const isBelowMinimum = formulaKcal < minimumDailyGuideEnergyKcal - floatingPointTolerance;
  const atLeastMinimumKcal = Math.max(formulaKcal, minimumDailyGuideEnergyKcal);
  const lowerKcal = previous.energyKcal - maximumWeeklyChangeKcal;
  const upperKcal = previous.energyKcal + maximumWeeklyChangeKcal;
  const isWeeklyChangeLimited =
    atLeastMinimumKcal < lowerKcal - floatingPointTolerance ||
    atLeastMinimumKcal > upperKcal + floatingPointTolerance;
  // 前の週の1日の目安は 1,200 kcal 以上なので、抑えても下限を割らない
  const unroundedKcal = Math.min(Math.max(atLeastMinimumKcal, lowerKcal), upperKcal);
  const energyKcal = roundToFiftyKcal(unroundedKcal);
  return {
    energyKcal,
    ...computeMacronutrientGuides({ energyKcal, targetWeightKg: goal.targetWeightKg }),
    limitHits: [
      ...(isWeeklyChangeLimited ? (["weekly_change"] as const) : []),
      ...(pace.isLimited ? (["required_pace"] as const) : []),
      // 1週の変化で下限より上に止まったときは、下限で決まった値ではないので当たったことにしない
      ...(isBelowMinimum && !isWeeklyChangeLimited ? (["minimum_energy"] as const) : []),
    ],
    mainReason: computeMainReason({ unroundedKcal, expenditureKcal, previous }),
  };
};

// 1日の目安の変化を、推定消費カロリーの変化と、1日に減らす（足す）分の変化に分け、大きいほう。同じなら推定消費カロリーの変化。
// 丸めの分で入れ替わらないよう、50 kcal に丸める前の値で分ける
const computeMainReason = ({
  unroundedKcal,
  expenditureKcal,
  previous,
}: {
  unroundedKcal: number;
  expenditureKcal: number;
  previous: { energyKcal: number; expenditureKcal: number };
}): DailyGuideMainReason => {
  const expenditureChangeKcal = expenditureKcal - previous.expenditureKcal;
  const balanceChangeKcal =
    unroundedKcal - expenditureKcal - (previous.energyKcal - previous.expenditureKcal);
  return Math.abs(balanceChangeKcal) > Math.abs(expenditureChangeKcal) + floatingPointTolerance
    ? "balance_change"
    : "expenditure_change";
};

// 前の週の1日の目安からの変化の上限。出荷後に調整する初期値
const maximumWeeklyChangeKcal = 150;
