import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { addDays } from "../../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../../domain/compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../../../domain/is-time-zone-name";
import { isWithinAcceptedRange } from "../../../domain/is-within-accepted-range";
import { millisecondsPerDay } from "../../../domain/milliseconds-per-day";
import { computeInitialExpenditureEstimate } from "../../../expenditure-estimate/domain/compute-initial-expenditure-estimate";
import { readRecordedEnergyIntakes } from "../../../expenditure-estimate/domain/read-recorded-energy-intakes";
import { readDailyWeights } from "../../../weight-trend/domain/read-daily-weights";
import { computeWeightTrend } from "../../../weight-trend/domain/compute-weight-trend";
import { findWeightTrendOnOrBefore } from "../../../weight-trend/domain/find-weight-trend-on-or-before";
import type { Goal } from "../goal";
import type { GoalSetupExpenditure } from "../goal-setup-expenditure";
import { GoalSetupRequestRejectedError } from "../goal-setup-request-rejected-error";
import type { GoalSetupStores } from "../goal-setup-stores";
import type { GoalSetupSituation } from "../goal-setup-situation";

// 目標の設定の計算の元。そのときの記録と、要求に載った端末の事情から、要求のたびに出し直す（何も残さない）
export type GoalSetupBasis = {
  // 開始の日（YYYY-MM-DD）
  startedOn: string;
  // 無ければ初めての目標
  currentGoal: Goal | undefined;
  // 体重記録が1つも無い人には無い
  startingWeightTrend: StartingWeightTrend | undefined;
  // 初めての目標で、逆算できず、式に使う値も揃っていないときは無い
  expenditure: GoalSetupExpenditure | undefined;
};

export type StartingWeightTrend = {
  trendKg: number;
  // 体重の傾向の元になった、開始の日以前で最後の体重記録の日
  lastWeightRecordedOn: string;
};

export const resolveGoalSetupBasis = (
  stores: GoalSetupStores,
  situation: GoalSetupSituation,
  now: Date,
): R.Result<GoalSetupBasis, GoalSetupRequestRejectedError> =>
  R.pipe(
    validateSituation(situation),
    R.andThen(() => {
      const today = computeCalendarDayInTimeZone(now, situation.timeZone);
      const currentGoal = stores.goal.findCurrent();
      // 開始の日は端末の今日。立て直すとき、西へ移って今日が今の目標の開始の日より前になっても、開始の日を戻さない
      const startedOn =
        currentGoal !== undefined && today < currentGoal.startedOn ? currentGoal.startedOn : today;
      const dailyWeights = readDailyWeights(stores.weightRecord);
      const trend = findWeightTrendOnOrBefore(computeWeightTrend(dailyWeights), startedOn);
      const lastWeightRecordedOn = dailyWeights.findLast(
        ({ calendarDay }) => calendarDay <= startedOn,
      )?.calendarDay;
      const startingWeightTrend =
        trend === undefined || lastWeightRecordedOn === undefined
          ? undefined
          : { trendKg: trend.trendKg, lastWeightRecordedOn };
      return R.pipe(
        currentGoal === undefined
          ? estimateInitialExpenditure(stores, situation, {
              today,
              dailyWeights,
              startingWeightTrendKg: startingWeightTrend?.trendKg,
            })
          : R.succeed(readCurrentExpenditure(stores)),
        R.map((expenditure) => ({ startedOn, currentGoal, startingWeightTrend, expenditure })),
      );
    }),
  );

// 身体データの範囲は、逆算できて式を使わない人でも確かめる（範囲の外は不具合のときだけ届く）
const validateSituation = ({
  timeZone,
  bodyData,
}: GoalSetupSituation): R.Result<void, GoalSetupRequestRejectedError> => {
  if (!isTimeZoneName(timeZone)) {
    return R.fail(new GoalSetupRequestRejectedError({ reason: "invalid_time_zone" }));
  }
  if (
    bodyData !== undefined &&
    !(
      isWithinAcceptedRange("heightCentimeters", bodyData.heightCentimeters) &&
      isWithinAcceptedRange("ageYears", bodyData.ageYears)
    )
  ) {
    return R.fail(new GoalSetupRequestRejectedError({ reason: "body_data_out_of_range" }));
  }
  return R.succeed();
};

const estimateInitialExpenditure = (
  stores: GoalSetupStores,
  { preUseEnergyIntakes, bodyData }: GoalSetupSituation,
  {
    today,
    dailyWeights,
    startingWeightTrendKg,
  }: {
    today: string;
    dailyWeights: readonly { calendarDay: string; weightKg: number }[];
    startingWeightTrendKg: number | undefined;
  },
): R.Result<GoalSetupExpenditure | undefined, never> => {
  // 初期値の窓（今日を除く直前の 28 日）より広く読む。食事の日は食事の時差で決まるので、1日の余裕を足す
  const since = new Date(Date.parse(`${addDays(today, -29)}T00:00:00Z`) - millisecondsPerDay);
  return R.pipe(
    computeInitialExpenditureEstimate({
      today,
      // 使い始めた日が読めない人は、どの日も使い始める前とみなす
      startedUsingOn: stores.firstSignIn.findStartedOn() ?? today,
      deviceEnergyIntakes: preUseEnergyIntakes,
      recordedEnergyIntakes: readRecordedEnergyIntakes(stores, since),
      dailyWeights,
      startingWeightTrendKg,
      bodyData,
    }),
    R.orElse((error) =>
      match(error)
        .returnType<R.Result<undefined, never>>()
        .with({ name: "FormulaInputsMissingError" }, () => R.succeed(undefined))
        .exhaustive(),
    ),
  );
};

// 立て直すときは推定を作らない。目標を決めるたびに1日の目安が推定を指すので、目標があれば推定もある
const readCurrentExpenditure = (stores: GoalSetupStores): GoalSetupExpenditure => {
  const estimate = stores.expenditureEstimate.findCurrent();
  if (estimate === undefined) {
    throw new Error("今の目標があるのに、推定消費カロリーの推定が無い");
  }
  return {
    source: "current",
    kcal: estimate.expenditureKcal,
    expenditureEstimateId: estimate.id,
  };
};
