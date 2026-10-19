import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { computeDailyRepresentativeWeights } from "../../weight-record/domain/compute-daily-representative-weights";
import { computeWeightTrend } from "../../weight-trend/domain/compute-weight-trend";
import { findAchievedDay } from "./find-achieved-day";
import { judgeDeadlineConfirmation } from "./judge-deadline-confirmation";
import { writeGoalAchievement, writeGoalDeadlineConfirmation } from "./write-goal-progress";

// 達成と期限の日の結果を判定して書く。記録を当てたあと、まだ見直していない週を見る前に呼ぶ。
// 達成は今の目標だけを見る。期限の日の確定は、期限の日以降に閉じた目標も見る。
// 達成を先に見るので、期限の日の翌日の最初の要求で届いた期限の日以前の体重は、確定の前の達成として数える。
// 書き込みは記録の変化を書く入口の1つの run にし、変えた目標の記録は同期で届く
export const judgeGoalProgress = (
  writeRecordChanges: RecordChangeWriter,
  stores: Pick<RecordKindStores, "goal" | "weightRecord">,
  { timeZone, now }: { timeZone: string; now: Date },
): void => {
  // 同期の要求のタイムゾーンは形しか確かめていないので、読めない要求では日を決めず、次の要求に任せる
  if (!isTimeZoneName(timeZone)) {
    return;
  }
  const goals = stores.goal.findAll();
  if (goals.length === 0) {
    return;
  }
  const weightTrend = computeWeightTrend(
    computeDailyRepresentativeWeights(stores.weightRecord.findAllInMeasuredOrder()).map(
      ({ calendarDay, weightRecord }) => ({ calendarDay, weightKg: weightRecord.weightKg }),
    ),
  );
  const today = computeCalendarDayInTimeZone(now, timeZone);
  const currentGoal = stores.goal.findCurrent();
  const achievedOn =
    currentGoal === undefined || currentGoal.achievement !== undefined
      ? undefined
      : findAchievedDay({ goal: currentGoal, weightTrend });
  const confirmations = goals.flatMap((goal) => {
    const confirmation = judgeDeadlineConfirmation({ goal, today, weightTrend });
    return confirmation === undefined ? [] : [{ goalId: goal.id, ...confirmation }];
  });
  if (achievedOn === undefined && confirmations.length === 0) {
    return;
  }
  writeRecordChanges(({ addChange }) => {
    if (currentGoal !== undefined && achievedOn !== undefined) {
      writeGoalAchievement(stores.goal, addChange, {
        goalId: currentGoal.id,
        achievement: { achievedOn, judgedAt: now, timeZone },
      });
    }
    for (const { goalId, deadlineWeightTrendKg } of confirmations) {
      writeGoalDeadlineConfirmation(stores.goal, addChange, {
        goalId,
        confirmation: { deadlineWeightTrendKg, confirmedAt: now, timeZone },
      });
    }
  });
};
