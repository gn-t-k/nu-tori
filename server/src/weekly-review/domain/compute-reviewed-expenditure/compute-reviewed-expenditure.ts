import { match } from "ts-pattern";
import { kilocaloriesPerKilogram } from "../../../domain/kilocalories-per-kilogram";
import type {
  ExpenditureDeviationDirection,
  InitialExpenditureSource,
} from "../../../expenditure-estimate/domain/expenditure-estimate";
import { floatingPointTolerance } from "../../../domain/floating-point-tolerance";
import { daysPerWeek } from "../../../domain/days-per-week";

export type ReviewedExpenditureInputs = {
  // 見直す週に当たっていた推定（最も遅い推定）
  previousExpenditureKcal: number;
  // 見直す週の、食事を記録した日の食べた量の平均
  averageEnergyIntakeKcal: number;
  recordedMealDayCount: number;
  // 見直す週の実際の体重の傾向の変化と、それを測った日数（judgeReviewWeek が出す）
  actualWeightChangeKg: number;
  weightChangeDayCount: number;
  // 推定の始まりの出どころ。読めなければ undefined（式とみなす）
  initialExpenditureSource: InitialExpenditureSource | undefined;
  // 前に見直した週（見送りを含む）。古い週から順に。見直せた週は、その週に食事を記録した日数を添える
  previousWeeks: readonly (
    | { type: "deferred" }
    | { type: "reviewed"; recordedMealDayCount: number }
  )[];
};

// 見直せた週の、新しい推定消費カロリー。推定消費カロリーを1つの状態とみるカルマンフィルタで、前の推定 + ρ × ずれ ÷ 測った日数 を観測として、前の推定から観測へ k の割合だけ動かす。
// 予測は実際の変化と同じ日数で出す。
// k は推定の不確かさ P から出し、P は推定の始まりから見直した週の並びをたどって毎回出し直す（P を残さないので、表を変えずに今までの見直しにも当てられる）。
// 1回の動きは上限で止める。始まりのころは k が大きく、記録の抜けや体重のぶれの1週がそのまま大きく乗るため。
// 止めても P は止めないときと同じに縮める（見直した週の並びだけからたどり直す形を保つ。k は Q で 0.18 ほどより下がらないので、止めた分はあとの週で戻せる）
export const computeReviewedExpenditure = ({
  previousExpenditureKcal,
  averageEnergyIntakeKcal,
  recordedMealDayCount,
  actualWeightChangeKg,
  weightChangeDayCount,
  initialExpenditureSource,
  previousWeeks,
}: ReviewedExpenditureInputs): {
  predictedWeightChangeKg: number;
  deviationKg: number;
  // 観測のうち推定を動かした割合（カルマンゲイン k）
  gain: number;
  // 上限で止める前の動き（k × 観測 − 前の推定）が上限を越えたか
  hitAdjustmentLimit: boolean;
  expenditureKcal: number;
  deviationDirection: ExpenditureDeviationDirection;
} => {
  const predictedWeightChangeKg =
    ((averageEnergyIntakeKcal - previousExpenditureKcal) * weightChangeDayCount) /
    kilocaloriesPerKilogram;
  const deviationKg = predictedWeightChangeKg - actualWeightChangeKg;
  const gain = computeGain(
    computeVarianceBeforeReview(initialExpenditureSource, previousWeeks),
    recordedMealDayCount,
  );
  const adjustmentKcal = (gain * kilocaloriesPerKilogram * deviationKg) / weightChangeDayCount;
  return {
    predictedWeightChangeKg,
    deviationKg,
    gain,
    hitAdjustmentLimit: Math.abs(adjustmentKcal) > maximumAdjustmentKcal,
    expenditureKcal: Math.round(
      previousExpenditureKcal +
        Math.min(Math.max(adjustmentKcal, -maximumAdjustmentKcal), maximumAdjustmentKcal),
    ),
    deviationDirection: toDeviationDirection(deviationKg),
  };
};

// 見直す週の、観測を当てる前の推定の分散（P⁻、kcal²）。
// 週ごとに本当の消費の動きの分だけ増やし、見直せた週はその週の k で減らす。見送った週は観測が無いので増やすだけにする
const computeVarianceBeforeReview = (
  initialExpenditureSource: InitialExpenditureSource | undefined,
  previousWeeks: ReviewedExpenditureInputs["previousWeeks"],
): number =>
  previousWeeks.reduce(
    (variance, week) => {
      const predicted = variance + weeklyProcessNoiseKcal ** 2;
      return match(week)
        .with({ type: "deferred" }, () => predicted)
        .with(
          { type: "reviewed" },
          ({ recordedMealDayCount }) =>
            predicted * (1 - computeGain(predicted, recordedMealDayCount)),
        )
        .exhaustive();
    },
    initialUncertaintyKcal(initialExpenditureSource) ** 2,
  ) +
  weeklyProcessNoiseKcal ** 2;

// 観測のぶれは、食事を記録した日が少ないほど大きいとみなす（7 日の週の R² × 7 ÷ 記録した日数）
const computeGain = (varianceBeforeReview: number, recordedMealDayCount: number): number =>
  varianceBeforeReview /
  (varianceBeforeReview + (observationNoiseKcal ** 2 * daysPerWeek) / recordedMealDayCount);

// 浮動小数の誤差で、等しい値の引き算を正か負にしない
const toDeviationDirection = (deviationKg: number): ExpenditureDeviationDirection => {
  if (Math.abs(deviationKg) < floatingPointTolerance) {
    return "zero";
  }
  return deviationKg > 0 ? "positive" : "negative";
};

// 推定の始まりの不確かさ（P₀ の標準偏差）。使い始める前の記録から逆算した推定は、式より確か
const initialUncertaintyKcal = (source: InitialExpenditureSource | undefined): number =>
  match(source)
    .with("back_calculated", () => 200)
    .with("formula", undefined, () => 400)
    .exhaustive();

// 本当の消費が1週で動く大きさ（Q）と、7 日記録した週の観測のぶれ（R）。どれも試算で選んだ、出荷後に実データで調整する初期値
const weeklyProcessNoiseKcal = 40;
const observationNoiseKcal = 200;

// 1回の見直しで推定を動かす上限。試算で、記録が正しい人の式で始めた最初の見直しの動きの 80% 点のあたり。出荷後に実データで調整する初期値
const maximumAdjustmentKcal = 250;
