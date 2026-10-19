import { computeReviewedDailyGuide } from "../../daily-guide/domain/compute-reviewed-daily-guide";
import type { RequiredPaceGoal } from "../../daily-guide/domain/required-pace";
import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import { millisecondsPerDay } from "../../domain/milliseconds-per-day";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { readRecordedEnergyIntakes } from "../../expenditure-estimate/domain/read-recorded-energy-intakes";
import { countDaysInclusive } from "../../goal/domain/accepted-deadline/count-days-inclusive";
import { computeGoalDirection } from "../../goal/domain/compute-goal-direction";
import type { Goal } from "../../goal/domain/goal";
import { planPostDeadlineMaintenance } from "../../goal/domain/plan-post-deadline-maintenance";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import { computeWeightTrend } from "../../weight-trend/domain/compute-weight-trend";
import { computeDailyRepresentativeWeights } from "../../weight-record/domain/compute-daily-representative-weights";
import { computeReviewedExpenditure } from "./compute-reviewed-expenditure";
import { findUnreviewedWeekMondays } from "./find-unreviewed-week-mondays";
import { judgeReviewWeek, type ReviewWeekJudgement } from "./judge-review-week";
import { type WeeklyReviewToWrite, writeWeeklyReview } from "./write-weekly-review";

export type WeeklyReviewStores = Pick<
  RecordKindStores,
  | "weeklyReview"
  | "goal"
  | "expenditureEstimate"
  | "dailyGuide"
  | "weightRecord"
  | "firstSignIn"
  | "meal"
  | "dish"
  | "ingredient"
>;

// まだ見直していない週を古い順に1週ずつ見て、見送るか、新しい推定と1日の目安をその月曜から当てて書く。
// 週の区切りと今日は要求のタイムゾーンで決める。
// 記録を当てたあと、応える前に呼ぶ。1つの週を記録の変化を書く入口の1つの run にし、変えた記録は同期で届く
export const reviewUnreviewedWeeks = (
  writeRecordChanges: RecordChangeWriter,
  stores: WeeklyReviewStores,
  { timeZone, now }: { timeZone: string; now: Date },
): void => {
  // 同期の要求のタイムゾーンは形しか確かめていないので、読めない要求では日を決めず、次の要求に任せる
  if (!isTimeZoneName(timeZone)) {
    return;
  }
  const latestEstimate = stores.expenditureEstimate.findCurrent();
  const mondays = findUnreviewedWeekMondays({
    today: computeCalendarDayInTimeZone(now, timeZone),
    firstGoalStartedOn: stores.goal
      .findAll()
      .map(({ startedOn }) => startedOn)
      .toSorted()
      .at(0),
    latestReviewEffectiveOn: stores.weeklyReview.findLatest()?.effectiveOn,
    latestEstimateEffectiveOn: latestEstimate?.effectiveOn,
  });
  const firstMonday = mondays.at(0);
  if (firstMonday === undefined || latestEstimate === undefined) {
    return;
  }
  const initialExpenditureSource = stores.expenditureEstimate
    .findEffectiveOnOrBefore(latestEstimate.effectiveOn)
    .find(({ initialSource }) => initialSource !== undefined)?.initialSource;
  const dailyWeights = computeDailyRepresentativeWeights(
    stores.weightRecord.findAllInMeasuredOrder(),
  ).map(({ calendarDay, weightRecord }) => ({ calendarDay, weightKg: weightRecord.weightKg }));
  // 最初の月曜の前の 28 日より広く読む。食事の日は食事の時差で決まるので、1日の余裕を足す
  const recordedEnergyIntakes = readRecordedEnergyIntakes(
    stores,
    new Date(Date.parse(`${addDays(firstMonday, -28)}T00:00:00Z`) - millisecondsPerDay),
  );
  const startedUsingOn = stores.firstSignIn.findStartedOn();
  const weightTrend = computeWeightTrend(dailyWeights);

  for (const reviewedMonday of mondays) {
    const judgement = judgeReviewWeek({
      reviewedMonday,
      startedUsingOn,
      initialExpenditureSource,
      dailyWeights,
      recordedEnergyIntakes,
    });
    const currentGoal = stores.goal.findCurrent();
    if (currentGoal === undefined) {
      throw new Error("目標があるのに、今の目標が無い");
    }
    // 期限のあと次の目標が選ばれないまま、期限の日より後の月曜が来たら、見送る週もその見直しで期限後の維持に移る
    const maintenance = planPostDeadlineMaintenance({
      goal: currentGoal,
      reviewedMonday,
      weightTrend,
    });
    const postDeadlineMaintenance =
      maintenance === undefined ? undefined : { ...maintenance, goalId: generateRecordId() };
    const reviewedGoalId = postDeadlineMaintenance?.goalId ?? currentGoal.id;
    // 前の週に書いた推定と1日の目安を読むので、計算も1週ずつ run の中で行う
    writeRecordChanges(({ addChange }) =>
      writeWeeklyReview(stores, addChange, {
        effectiveOn: reviewedMonday,
        reviewedAt: now,
        timeZone,
        postDeadlineMaintenance,
        outcome:
          judgement.type === "deferred"
            ? { type: "deferred", reason: judgement.reason, goalId: reviewedGoalId }
            : computeReviewedOutcome(stores, {
                currentGoal,
                reviewedGoalId,
                // 期限後の維持に移る週は、維持の式で出す
                requiredPaceGoal:
                  postDeadlineMaintenance === undefined
                    ? toRequiredPaceGoal(currentGoal, {
                        reviewedMonday,
                        weightTrendKg: judgement.sundayWeightTrendKg,
                      })
                    : {
                        direction: "maintain",
                        targetWeightKg: postDeadlineMaintenance.targetWeightKg,
                        weightTrendKg: judgement.sundayWeightTrendKg,
                      },
                reviewedMonday,
                judgement,
              }),
      }),
    );
  }
};

// 見直せた週の、新しい推定と、それを使った1日の目安。1日の目安は、今の目標か、期限後の維持に移る週は維持の目標に書き、
// 前の週からの変化は今の目標の前の週の1日の目安から抑える
const computeReviewedOutcome = (
  stores: WeeklyReviewStores,
  {
    currentGoal,
    reviewedGoalId,
    requiredPaceGoal,
    reviewedMonday,
    judgement,
  }: {
    currentGoal: Goal;
    reviewedGoalId: RecordId;
    requiredPaceGoal: RequiredPaceGoal;
    reviewedMonday: string;
    judgement: Extract<ReviewWeekJudgement, { type: "reviewable" }>;
  },
): Extract<WeeklyReviewToWrite["outcome"], { type: "reviewed" }> => {
  const previousEstimate = stores.expenditureEstimate.findCurrent();
  // 今の目標を決めるたびに1日の目安を書くので、目標の開始の日から当てる1日の目安がある
  const previousDailyGuide = stores.dailyGuide
    .findAll()
    .filter(({ goalId, effectiveOn }) => goalId === currentGoal.id && effectiveOn < reviewedMonday)
    .toSorted((left, right) => left.effectiveOn.localeCompare(right.effectiveOn))
    .at(-1);
  const previousDailyGuideEstimate =
    previousDailyGuide === undefined
      ? undefined
      : stores.expenditureEstimate.find(previousDailyGuide.expenditureEstimateId);
  if (
    previousEstimate === undefined ||
    previousDailyGuide === undefined ||
    previousDailyGuideEstimate === undefined
  ) {
    throw new Error("見直す週に当たっていた推定か1日の目安が無い");
  }
  const expenditure = computeReviewedExpenditure({
    previousExpenditureKcal: previousEstimate.expenditureKcal,
    averageEnergyIntakeKcal: judgement.averageEnergyIntakeKcal,
    recordedMealDayCount: judgement.recordedMealDayCount,
    actualWeightChangeKg: judgement.actualWeightChangeKg,
    previousWeeks: stores.weeklyReview.findDeviationHistory(),
  });
  const dailyGuide = computeReviewedDailyGuide({
    expenditureKcal: expenditure.expenditureKcal,
    previous: {
      energyKcal: previousDailyGuide.energyKcal,
      expenditureKcal: previousDailyGuideEstimate.expenditureKcal,
    },
    goal: requiredPaceGoal,
  });
  return {
    type: "reviewed",
    expenditure: {
      expenditureKcal: expenditure.expenditureKcal,
      deviationDirection: expenditure.deviationDirection,
    },
    dailyGuide: { ...dailyGuide, goalId: reviewedGoalId },
  };
};

// 見直しでは、M の前の日曜の体重の傾向と、M から期限の日までの日数で必要な速さを出す。上限は目標の開始の日の体重の傾向から出す
const toRequiredPaceGoal = (
  goal: Goal,
  { reviewedMonday, weightTrendKg }: { reviewedMonday: string; weightTrendKg: number },
): RequiredPaceGoal => {
  const direction = computeGoalDirection(goal);
  if (direction === "maintain" || goal.weightChange === undefined) {
    return { direction: "maintain", targetWeightKg: goal.targetWeightKg, weightTrendKg };
  }
  return {
    direction,
    goalStartingWeightTrendKg: goal.startingWeightTrendKg,
    targetWeightKg: goal.targetWeightKg,
    weightTrendKg,
    daysToDeadline: countDaysInclusive(reviewedMonday, goal.weightChange.deadlineOn),
  };
};
