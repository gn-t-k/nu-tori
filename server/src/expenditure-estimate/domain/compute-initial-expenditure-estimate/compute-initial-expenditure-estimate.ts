import { R } from "@praha/byethrow";
import { ErrorFactory } from "@praha/error-factory";
import { match } from "ts-pattern";
import { addDays } from "../../../domain/add-days";
import type { BodyData } from "../body-data";
import { computeActivityFactor } from "./compute-activity-factor";
import { computeBackCalculatedExpenditure } from "./compute-back-calculated-expenditure";

export type InitialExpenditureEstimate = { kcal: number; source: "back_calculated" | "formula" };

// 初めて目標を立てるときの推定消費カロリー。記録が足りれば逆算し、足りなければ式で出す。目標の向きでは変えない。
// 逆算できるかだけを知りたいとき（目標の下見）は、bodyData を undefined で呼び、FormulaInputsMissingError を逆算できないと読む
export const computeInitialExpenditureEstimate = ({
  today,
  startedUsingOn,
  deviceEnergyIntakes,
  recordedEnergyIntakes,
  dailyWeights,
  startingWeightTrendKg,
  bodyData,
}: {
  // 端末の今のタイムゾーンでの今日
  today: string;
  startedUsingOn: string;
  // 端末がヘルスケアから読んだ、日ごとの摂取エネルギー。使い始める前の日の食べた量にする
  deviceEnergyIntakes: readonly { calendarDay: string; kcal: number }[];
  // nu-tori の記録から出した、日ごとの食べた量。使い始めた日からの食べた量にする
  recordedEnergyIntakes: readonly { calendarDay: string; kcal: number }[];
  // 日の代表値
  dailyWeights: readonly { calendarDay: string; weightKg: number }[];
  // 開始の日の体重の傾向。体重記録が1つも無い人には無い
  startingWeightTrendKg: number | undefined;
  // 逆算できる人には尋ねないので無い
  bodyData: BodyData | undefined;
}): R.Result<InitialExpenditureEstimate, FormulaInputsMissingError> => {
  // 初期値の窓。今日は記録の途中なので入れない
  const windowDays = 28;
  const firstDay = addDays(today, -windowDays);
  const isInWindow = ({ calendarDay }: { calendarDay: string }): boolean =>
    firstDay <= calendarDay && calendarDay < today;

  const backCalculated = computeBackCalculatedExpenditure(
    [
      ...deviceEnergyIntakes.filter(({ calendarDay }) => calendarDay < startedUsingOn),
      ...recordedEnergyIntakes.filter(({ calendarDay }) => startedUsingOn <= calendarDay),
    ].filter(isInWindow),
    dailyWeights.filter(isInWindow),
  );
  if (backCalculated !== undefined) {
    return R.succeed({ kcal: Math.round(backCalculated), source: "back_calculated" });
  }

  if (bodyData === undefined || startingWeightTrendKg === undefined) {
    return R.fail(new FormulaInputsMissingError());
  }
  const activityFactor = computeActivityFactor(
    match(bodyData.activity)
      .with({ type: "steps" }, ({ type, dailySteps }) => ({
        type,
        dailySteps: dailySteps.filter(isInWindow),
      }))
      .with({ type: "level" }, (level) => level)
      .exhaustive(),
  );
  if (activityFactor === undefined) {
    return R.fail(new FormulaInputsMissingError());
  }
  return R.succeed({
    kcal: Math.round(computeRestingExpenditure(bodyData, startingWeightTrendKg) * activityFactor),
    source: "formula",
  });
};

// 逆算できず、式に使う値（身体データ、開始の日の体重の傾向、歩いた日のある歩数か3択の活動量）も揃っていない
export class FormulaInputsMissingError extends ErrorFactory({
  name: "FormulaInputsMissingError",
  message: "逆算できず、推定消費カロリーの式に使う値が足りない",
}) {}

// Mifflin-St Jeor の式
const computeRestingExpenditure = (
  { sex, heightCentimeters, ageYears }: BodyData,
  weightKg: number,
): number =>
  10 * weightKg +
  6.25 * heightCentimeters -
  5 * ageYears +
  match(sex)
    .with("male", () => 5)
    .with("female", () => -161)
    .exhaustive();
