import { addDays } from "../../domain/add-days";
import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import { millisecondsPerDay } from "../../domain/milliseconds-per-day";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { readRecordedEnergyIntakes } from "../../expenditure-estimate/domain/read-recorded-energy-intakes";
import { computeDailyRepresentativeWeights } from "../../weight-record/domain/compute-daily-representative-weights";
import { findUnreviewedWeekMondays } from "./find-unreviewed-week-mondays";
import { judgeReviewWeek } from "./judge-review-week";
import { writeWeeklyReview } from "./write-weekly-review";

export type WeeklyReviewStores = Pick<
  RecordKindStores,
  | "weeklyReview"
  | "goal"
  | "expenditureEstimate"
  | "weightRecord"
  | "firstSignIn"
  | "meal"
  | "dish"
  | "ingredient"
>;

// まだ見直していない週を古い順に1週ずつ見て、見送る週を書く。週の区切りと今日は要求のタイムゾーンで決める。
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

  for (const reviewedMonday of mondays) {
    const judgement = judgeReviewWeek({
      reviewedMonday,
      startedUsingOn,
      initialExpenditureSource,
      dailyWeights,
      recordedEnergyIntakes,
    });
    // 見直せる週は次のチケット（#618）で書く。それまでは書かず、見直した週に数えない
    if (judgement.type === "reviewable") {
      continue;
    }
    const currentGoal = stores.goal.findCurrent();
    if (currentGoal === undefined) {
      throw new Error("目標があるのに、今の目標が無い");
    }
    writeRecordChanges(({ addChange }) =>
      writeWeeklyReview(stores, addChange, {
        effectiveOn: reviewedMonday,
        reviewedAt: now,
        timeZone,
        deferral: { reason: judgement.reason, goalId: currentGoal.id },
      }),
    );
  }
};
