import { kilocaloriesPerKilogram } from "../../../domain/kilocalories-per-kilogram";
import type { ExpenditureDeviationDirection } from "../../../expenditure-estimate/domain/expenditure-estimate";

export type ReviewedExpenditureInputs = {
  // 見直す週に当たっていた推定（最も遅い推定）
  previousExpenditureKcal: number;
  // 見直す週の、食事を記録した日の食べた量の平均
  averageEnergyIntakeKcal: number;
  recordedMealDayCount: number;
  // M の前の日曜の体重の傾向 − その前の日曜の体重の傾向
  actualWeightChangeKg: number;
  // 前に見直した週（見送りを含む）。新しい週から順に
  previousWeeks: readonly (
    | { type: "deferred" }
    | { type: "reviewed"; deviationDirection: ExpenditureDeviationDirection }
  )[];
};

// 見直せた週の、新しい推定消費カロリー。予測した変化と実際の変化のずれの分だけ、前の推定を動かす
export const computeReviewedExpenditure = ({
  previousExpenditureKcal,
  averageEnergyIntakeKcal,
  recordedMealDayCount,
  actualWeightChangeKg,
  previousWeeks,
}: ReviewedExpenditureInputs): {
  predictedWeightChangeKg: number;
  deviationKg: number;
  expenditureKcal: number;
  deviationDirection: ExpenditureDeviationDirection;
} => {
  const predictedWeightChangeKg =
    ((averageEnergyIntakeKcal - previousExpenditureKcal) * daysPerWeek) / kilocaloriesPerKilogram;
  const deviationKg = predictedWeightChangeKg - actualWeightChangeKg;
  const deviationDirection = toDeviationDirection(deviationKg);
  const k = Math.min(
    baseGain *
      (recordedMealDayCount / daysPerWeek) *
      (1 + countContinuedWeeks(deviationDirection, previousWeeks)),
    maximumGain,
  );
  return {
    predictedWeightChangeKg,
    deviationKg,
    expenditureKcal: Math.round(
      previousExpenditureKcal + (k * kilocaloriesPerKilogram * deviationKg) / daysPerWeek,
    ),
    deviationDirection,
  };
};

// 浮動小数の誤差で、等しい値の引き算を正か負にしない
const toDeviationDirection = (deviationKg: number): ExpenditureDeviationDirection => {
  if (Math.abs(deviationKg) < tolerance) {
    return "zero";
  }
  return deviationKg > 0 ? "positive" : "negative";
};

// 続いた週の数。前に見直せた週と同じ向きなら1つ増やし、向きが変わるかずれが 0 の週で 0 に戻す。
// 見送った週は数を変えないので飛ばす。数は残さず、見直すたびに向きの並びから数え直す
const countContinuedWeeks = (
  deviationDirection: ExpenditureDeviationDirection,
  previousWeeks: ReviewedExpenditureInputs["previousWeeks"],
): number => {
  if (deviationDirection === "zero") {
    return 0;
  }
  const reviewedDirections = previousWeeks.flatMap((week) =>
    week.type === "reviewed" ? [week.deviationDirection] : [],
  );
  const changedAt = reviewedDirections.findIndex((direction) => direction !== deviationDirection);
  return changedAt === -1 ? reviewedDirections.length : changedAt;
};

const daysPerWeek = 7;

// k の係数と上限。出荷後に調整する初期値
const baseGain = 0.25;
const maximumGain = 0.75;

const tolerance = 1e-9;
