// 出し方のページの例の数字が本番の決まりとずれないよう、本番と同じドメイン層の関数で架空の1人の4週間を回す
import { addDays } from "../src/domain/add-days";
import { countDaysBetween } from "../src/domain/count-days-between";
import { computeDailyGuideEnergy } from "../src/daily-guide/domain/compute-daily-guide-energy";
import { computeRequiredPace } from "../src/daily-guide/domain/compute-required-pace";
import { computeReviewedDailyGuide } from "../src/daily-guide/domain/compute-reviewed-daily-guide";
import {
  computeActivityFactor,
  computeInitialExpenditureEstimate,
} from "../src/expenditure-estimate/domain/compute-initial-expenditure-estimate";
import { daysPerWeek } from "../src/domain/days-per-week";
import { kilocaloriesPerKilogram } from "../src/domain/kilocalories-per-kilogram";
import { computeReviewedExpenditure } from "../src/weekly-review/domain/compute-reviewed-expenditure";
import { judgeReviewWeek } from "../src/weekly-review/domain/judge-review-week";
import { computeWeightTrend } from "../src/weight-trend/domain/compute-weight-trend";

const startedOn = "2026-01-05"; // 月曜
const startingWeightKg = 78.4;
const body = { sex: "male", heightCentimeters: 172, ageYears: 30 } as const;
const activity = { type: "level", level: "sedentary" } as const;
const targetWeightKg = 74.4;
const goalWeeks = 12;
const deadline = addDays(startedOn, 7 * goalWeeks - 1);
const weeks = 4;

// 本当に使うカロリー（説明のための仮定で、nu-tori は知らない値）。体重が 1 kg 減ると 1日 27 kcal 減る
const trueExpenditureKcalPerKg = 27;
const trueExpenditureAt = (weightKg: number) =>
  2150 + trueExpenditureKcalPerKg * (weightKg - startingWeightKg);
// 毎朝の体重の上下（水分など）。決まった並びにして、回すたびに同じ値にする
const priorDayCount = 28;
const waterNoiseKg = (dayIndex: number) => {
  const x = Math.sin((dayIndex + priorDayCount + 6) * 12.9898) * 43758.5453;
  return Math.round((x - Math.floor(x) - 0.5) * 10) / 10;
};
// 食べた量の日々のぶれ。週ごとに足すと 0 になる
const intakeNoiseKcal = [120, -80, 200, -150, 60, -250, 100] as const;

const round = (value: number, digits: number) => Number(value.toFixed(digits));

// 使い始める前は、本当に使うカロリーと同じだけ食べていて、体重が変わらなかった。
// 体重計の記録はヘルスケアにあるが、食事は記録していなかったので、逆算はできない
const priorWeights = Array.from({ length: priorDayCount }, (_, i) => ({
  calendarDay: addDays(startedOn, i - priorDayCount),
  weightKg: Math.round((startingWeightKg + waterNoiseKg(i - priorDayCount)) * 10) / 10,
}));
const startingWeightTrendKg = computeWeightTrend(priorWeights).at(-1)?.trendKg;
if (startingWeightTrendKg === undefined) throw new Error("使い始める前の体重が無い");
const initial = computeInitialExpenditureEstimate({
  today: startedOn,
  startedUsingOn: startedOn,
  deviceEnergyIntakes: [],
  recordedEnergyIntakes: [],
  dailyWeights: priorWeights,
  startingWeightTrendKg,
  bodyData: { ...body, activity },
});
if (initial.type === "Failure") throw initial.error;
const activityFactor = computeActivityFactor(activity);
if (activityFactor === undefined) throw new Error("活動量の係数が出ない");
const daysFromStartToDeadline = countDaysBetween(startedOn, deadline) + 1;
const requiredPaceKgPerDay = computeRequiredPace({
  direction: "lose",
  goalStartingWeightTrendKg: startingWeightTrendKg,
  targetWeightKg,
  weightTrendKg: startingWeightTrendKg,
  daysToDeadline: daysFromStartToDeadline,
}).kgPerDay;
const initialGuide = computeDailyGuideEnergy({
  expenditureKcal: initial.value.kcal,
  goal: { direction: "lose", startingWeightTrendKg, targetWeightKg, daysFromStartToDeadline },
});

let expenditureKcal = initial.value.kcal;
let guideKcal = initialGuide.energyKcal;
let trueWeightKg = startingWeightKg;
const days: { calendarDay: string; weightKg: number; kcal: number; trueExpenditureKcal: number }[] =
  [];
const reviews = [];
const previousWeeks: Parameters<typeof computeReviewedExpenditure>[0]["previousWeeks"][number][] =
  [];

for (let week = 0; week < weeks; week++) {
  for (const [d, intakeNoise] of intakeNoiseKcal.entries()) {
    const index = week * 7 + d;
    const kcal = guideKcal + intakeNoise;
    const trueExpenditureKcal = trueExpenditureAt(trueWeightKg);
    days.push({
      calendarDay: addDays(startedOn, index),
      weightKg: Math.round((trueWeightKg + waterNoiseKg(index)) * 10) / 10,
      kcal,
      trueExpenditureKcal,
    });
    trueWeightKg += (kcal - trueExpenditureKcal) / kilocaloriesPerKilogram;
  }
  const reviewedMonday = addDays(startedOn, (week + 1) * 7);
  const judgement = judgeReviewWeek({
    reviewedMonday,
    startedUsingOn: startedOn,
    initialExpenditureSource: initial.value.source,
    dailyWeights: [
      ...priorWeights,
      ...days.map(({ calendarDay, weightKg }) => ({ calendarDay, weightKg })),
    ],
    recordedEnergyIntakes: days.map(({ calendarDay, kcal }) => ({ calendarDay, kcal })),
  });
  if (judgement.type !== "reviewable") throw new Error(JSON.stringify(judgement));
  const reviewed = computeReviewedExpenditure({
    previousExpenditureKcal: expenditureKcal,
    averageEnergyIntakeKcal: judgement.averageEnergyIntakeKcal,
    recordedMealDayCount: judgement.recordedMealDayCount,
    actualWeightChangeKg: judgement.actualWeightChangeKg,
    previousWeeks,
  });
  const guide = computeReviewedDailyGuide({
    expenditureKcal: reviewed.expenditureKcal,
    previous: { energyKcal: guideKcal, expenditureKcal },
    goal: {
      direction: "lose",
      goalStartingWeightTrendKg: startingWeightTrendKg,
      targetWeightKg,
      weightTrendKg: judgement.sundayWeightTrendKg,
      daysToDeadline: countDaysBetween(reviewedMonday, deadline) + 1,
    },
  });
  const deviationKcalPerDay = (kilocaloriesPerKilogram * reviewed.deviationKg) / daysPerWeek;
  reviews.push({
    weekFirstDay: addDays(reviewedMonday, -daysPerWeek),
    weekLastDay: addDays(reviewedMonday, -1),
    previousExpenditureKcal: expenditureKcal,
    averageEnergyIntakeKcal: judgement.averageEnergyIntakeKcal,
    recordedMealDayCount: judgement.recordedMealDayCount,
    predictedWeightChangeKg: round(reviewed.predictedWeightChangeKg, 4),
    actualWeightChangeKg: round(judgement.actualWeightChangeKg, 4),
    deviationKg: round(reviewed.deviationKg, 4),
    deviationKcalPerDay: round(Math.abs(deviationKcalPerDay), 1),
    gain: reviewed.gain,
    adjustedKcal: round(Math.abs(deviationKcalPerDay) * reviewed.gain, 1),
    expenditureKcal: reviewed.expenditureKcal,
    guideKcal: guide.energyKcal,
    limitHits: guide.limitHits,
  });
  previousWeeks.unshift({ type: "reviewed", deviationDirection: reviewed.deviationDirection });
  expenditureKcal = reviewed.expenditureKcal;
  guideKcal = guide.energyKcal;
}

const trend = computeWeightTrend([
  ...priorWeights,
  ...days.map(({ calendarDay, weightKg }) => ({ calendarDay, weightKg })),
]);
const withTrend = (day: { calendarDay: string; weightKg: number }, i: number) => {
  const point = trend[i];
  if (point === undefined) throw new Error(`${day.calendarDay} の体重の傾向が無い`);
  return { calendarDay: day.calendarDay, weightKg: day.weightKg, trendKg: round(point.trendKg, 4) };
};

// 4週目のあと、見直さずに4週目の1日の目安を食べ続けたら（本当に使うカロリーの仮定だけで動く。nu-tori の決まりではない）
const plateau: { week: number; trueWeightKg: number }[] = [];
{
  let weightKg = trueWeightKg;
  for (let day = 0; day <= 7 * 104; day++) {
    if (day % 28 === 0) plateau.push({ week: weeks + day / 7, trueWeightKg: round(weightKg, 4) });
    weightKg += (guideKcal - trueExpenditureAt(weightKg)) / kilocaloriesPerKilogram;
  }
}

console.log(
  JSON.stringify(
    {
      person: {
        ...body,
        targetWeightKg,
        goalWeeks,
        daysFromStartToDeadline,
        activityFactor,
        trueExpenditureKcalPerKg,
      },
      initial: {
        kcal: initial.value.kcal,
        restingKcal: round(initial.value.kcal / activityFactor, 1),
        startingWeightTrendKg: round(startingWeightTrendKg, 4),
        // 期限までに目標体重へ届く、体重の傾向の1日の減り方と、その kcal。1日の目安は、推定からこの kcal を引いて丸めた値
        requiredPaceKgPerDay: round(Math.abs(requiredPaceKgPerDay), 4),
        requiredPaceKcalPerDay: round(Math.abs(requiredPaceKgPerDay) * kilocaloriesPerKilogram, 1),
        unroundedGuideKcal: round(
          initial.value.kcal + requiredPaceKgPerDay * kilocaloriesPerKilogram,
          1,
        ),
        guideKcal: initialGuide.energyKcal,
      },
      // 図に出すのは、使い始める前の 14 日から
      priorDays: priorWeights.map(withTrend).slice(-14),
      days: days.map((day, i) => ({
        ...withTrend(day, priorDayCount + i),
        trueExpenditureKcal: round(day.trueExpenditureKcal, 1),
      })),
      reviews,
      plateau,
    },
    null,
    2,
  ),
);
