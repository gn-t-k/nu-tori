// PROTOTYPE（#745）。試作の図と例の数字を、サーバーのドメイン層の関数をそのまま呼んで出す。
// 架空の1人が、式の推定消費カロリーで目標を立て、1日の目安どおりに食べ、毎朝体重を量った4週間を作り、
// 毎週の見直しを本番と同じ関数で回す。出した値は data.json に書き、index.html に手で写す。
// 回し方: cd server && pnpm exec tsx ../site/prototype/daily-guide-745/simulate.ts
import { writeFileSync } from "node:fs";
import { addDays } from "../../../server/src/domain/add-days";
import { computeInitialExpenditureEstimate } from "../../../server/src/expenditure-estimate/domain/compute-initial-expenditure-estimate";
import { computeDailyGuideEnergy } from "../../../server/src/daily-guide/domain/compute-daily-guide-energy";
import { computeReviewedDailyGuide } from "../../../server/src/daily-guide/domain/compute-reviewed-daily-guide";
import { judgeReviewWeek } from "../../../server/src/weekly-review/domain/judge-review-week";
import { computeReviewedExpenditure } from "../../../server/src/weekly-review/domain/compute-reviewed-expenditure";
import { computeWeightTrend } from "../../../server/src/weight-trend/domain/compute-weight-trend";
import { countDaysBetween } from "../../../server/src/domain/count-days-between";

// 架空の人。式の値がちょうど 2,400 kcal になる身体データにした
const startedOn = "2026-01-05"; // 月曜
const startingWeightKg = 78.4;
const body = { sex: "male", heightCentimeters: 172, ageYears: 30 } as const;
const targetWeightKg = 74.4;
const deadline = addDays(startedOn, 7 * 12 - 1);

// 本当の消費（試作の仮定で、nu-tori は知らない値）。体重が 1 kg 落ちると 1日 27 kcal 下がる
const trueExpenditureAt = (weightKg: number) => 2150 + 27 * (weightKg - startingWeightKg);
// 日々の揺れ（水分など）。決まった並びにして、回すたびに同じ値にする
const waterNoiseKg = (dayIndex: number) => {
  const x = Math.sin((dayIndex + priorDays + noiseSeed) * 12.9898) * 43758.5453;
  return Math.round((x - Math.floor(x) - 0.5) * noiseRange * 10) / 10;
};
// 使い始める前の 28 日も、体重計の記録はヘルスケアにある（食事は記録していなかったので、逆算はできない）
const priorDays = 28;
const noiseSeed = Number(process.env["SEED"] ?? 6);
const noiseRange = Number(process.env["RANGE"] ?? 1.0);
const weeks = Number(process.env["WEEKS"] ?? 4);
// 食べた量の日々のぶれ。週ごとに足すと 0 になる
const intakeNoiseKcal = [120, -80, 200, -150, 60, -250, 100];

// 使い始める前は、本当の消費と同じだけ食べていて体重が変わらなかった
const priorWeights = Array.from({ length: priorDays }, (_, i) => ({
  calendarDay: addDays(startedOn, i - priorDays),
  weightKg: Math.round((startingWeightKg + waterNoiseKg(i - priorDays)) * 10) / 10,
}));
const startingWeightTrendKg = computeWeightTrend(priorWeights).at(-1)!.trendKg;
const initial = computeInitialExpenditureEstimate({
  today: startedOn,
  startedUsingOn: startedOn,
  deviceEnergyIntakes: [],
  recordedEnergyIntakes: [],
  dailyWeights: priorWeights,
  startingWeightTrendKg,
  bodyData: { ...body, activity: { type: "level", level: "sedentary" } },
});
if (initial.type === "Failure") throw initial.error;
let expenditureKcal = initial.value.kcal;
const initialGuide = computeDailyGuideEnergy({
  expenditureKcal,
  goal: {
    direction: "lose",
    startingWeightTrendKg,
    targetWeightKg,
    daysFromStartToDeadline: countDaysBetween(startedOn, deadline) + 1,
  },
});
let guideKcal = initialGuide.energyKcal;

let trueWeightKg = startingWeightKg;
const days: {
  calendarDay: string;
  weightKg: number;
  trueWeightKg: number;
  kcal: number;
  trueExpenditureKcal: number;
}[] = [];
const reviews: unknown[] = [];
const previousWeeks: Parameters<typeof computeReviewedExpenditure>[0]["previousWeeks"][number][] =
  [];

for (let week = 0; week < weeks; week++) {
  for (let d = 0; d < 7; d++) {
    const index = week * 7 + d;
    const calendarDay = addDays(startedOn, index);
    const kcal = guideKcal + intakeNoiseKcal[d];
    const trueExpenditureKcal = trueExpenditureAt(trueWeightKg);
    days.push({
      calendarDay,
      weightKg: Math.round((trueWeightKg + waterNoiseKg(index)) * 10) / 10,
      trueWeightKg,
      kcal,
      trueExpenditureKcal,
    });
    trueWeightKg += (kcal - trueExpenditureKcal) / 7700;
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
  reviews.push({
    reviewedMonday,
    previousExpenditureKcal: expenditureKcal,
    previousGuideKcal: guideKcal,
    averageEnergyIntakeKcal: judgement.averageEnergyIntakeKcal,
    recordedMealDayCount: judgement.recordedMealDayCount,
    actualWeightChangeKg: judgement.actualWeightChangeKg,
    sundayWeightTrendKg: judgement.sundayWeightTrendKg,
    ...reviewed,
    guideKcal: guide.energyKcal,
    limitHits: guide.limitHits,
  });
  previousWeeks.unshift({ type: "reviewed", deviationDirection: reviewed.deviationDirection });
  expenditureKcal = reviewed.expenditureKcal;
  guideKcal = guide.energyKcal;
}

const fullTrend = computeWeightTrend([
  ...priorWeights,
  ...days.map(({ calendarDay, weightKg }) => ({ calendarDay, weightKg })),
]);
const trend = fullTrend.slice(priorDays);

// 4週目のあと、見直さずに今の1日の目安を食べ続けたら（本当の消費の仮定だけで動く。nu-tori の決まりではない）
const plateau: { week: number; trueWeightKg: number; trueExpenditureKcal: number }[] = [];
{
  let w = trueWeightKg;
  for (let day = 0; day <= 7 * 104; day++) {
    if (day % 28 === 0)
      plateau.push({
        week: weeks + day / 7,
        trueWeightKg: w,
        trueExpenditureKcal: trueExpenditureAt(w),
      });
    w += (guideKcal - trueExpenditureAt(w)) / 7700;
  }
}

const result = {
  initial: {
    ...initial.value,
    startingWeightTrendKg,
    guideKcal: initialGuide.energyKcal,
    limitHits: initialGuide.limitHits,
  },
  deadline,
  priorDays: priorWeights.map((day, i) => ({ ...day, trendKg: fullTrend[i].trendKg })),
  days: days.map((day, i) => ({ ...day, trendKg: trend[i].trendKg })),
  reviews,
  plateau,
};
writeFileSync(new URL("./data.json", import.meta.url), JSON.stringify(result, null, 2));
console.log(JSON.stringify({ initial: result.initial, reviews, plateau }, null, 1));
