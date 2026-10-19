import { computeCalendarDayInTimeZone } from "../../domain/compute-calendar-day-in-time-zone";
import { countDaysBetween } from "../../domain/count-days-between";
import type { UsageEvent } from "../../domain/usage-event";
import { isTimeZoneName } from "../../domain/is-time-zone-name";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import { computeDailyRepresentativeWeights } from "../../weight-record/domain/compute-daily-representative-weights";
import { computeWeightTrend } from "../../weight-trend/domain/compute-weight-trend";
import { findAchievedDay } from "./find-achieved-day";
import type { Goal } from "./goal";
import { roundToTenthKg } from "./round-to-tenth-kg";
import { judgeDeadlineConfirmation } from "./judge-deadline-confirmation";
import { writeGoalAchievement, writeGoalDeadlineConfirmation } from "./write-goal-progress";

// 達成と期限の日の結果を判定して書く。記録を当てたあと、まだ見直していない週を見る前に呼ぶ。
// 達成は今の目標だけを見る。期限の日の確定は、期限の日以降に閉じた目標も見る。
// 達成を先に見るので、期限の日の翌日の最初の要求で届いた期限の日以前の体重は、確定の前の達成として数える。
// 書き込みは記録の変化を書く入口の1つの run にし、変えた目標の記録は同期で届く。
// 書いた達成と確定ごとの出来事を返す。送るかどうかは呼ぶ側が決める
export const judgeGoalProgress = (
  writeRecordChanges: RecordChangeWriter,
  stores: Pick<RecordKindStores, "goal" | "weightRecord">,
  { timeZone, now }: { timeZone: string; now: Date },
): { usageEvents: UsageEvent[] } => {
  // 同期の要求のタイムゾーンは形しか確かめていないので、読めない要求では日を決めず、次の要求に任せる
  if (!isTimeZoneName(timeZone)) {
    return { usageEvents: [] };
  }
  const goals = stores.goal.findAll();
  if (goals.length === 0) {
    return { usageEvents: [] };
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
    return confirmation === undefined ? [] : [{ goal, ...confirmation }];
  });
  if (achievedOn === undefined && confirmations.length === 0) {
    return { usageEvents: [] };
  }
  writeRecordChanges(({ addChange }) => {
    if (currentGoal !== undefined && achievedOn !== undefined) {
      writeGoalAchievement(stores.goal, addChange, {
        goalId: currentGoal.id,
        achievement: { achievedOn, judgedAt: now, timeZone },
      });
    }
    for (const { goal, deadlineWeightTrendKg } of confirmations) {
      writeGoalDeadlineConfirmation(stores.goal, addChange, {
        goalId: goal.id,
        confirmation: { deadlineWeightTrendKg, confirmedAt: now, timeZone },
      });
    }
  });
  return {
    usageEvents: [
      ...(currentGoal === undefined || achievedOn === undefined
        ? []
        : [toAchievedEvent(currentGoal, achievedOn)]),
      ...confirmations.map(({ goal, deadlineWeightTrendKg }): UsageEvent => ({
        name: "goal_deadline_confirmed",
        // -0.04 kg のような差が -0 にならないよう、0 を足す
        differenceFromTargetKg:
          roundToTenthKg(deadlineWeightTrendKg - goal.targetWeightKg, "round") + 0,
        // 達成は今の目標だけを、確定より先に判定するので、この要求で達成した目標も達成していたことになる
        achieved:
          goal.achievement !== undefined ||
          (goal.id === currentGoal?.id && achievedOn !== undefined),
      })),
    ],
  };
};

const toAchievedEvent = (goal: Goal, achievedOn: string): UsageEvent => {
  // 達成は減量・増量の目標にだけある
  if (goal.weightChange === undefined) {
    throw new Error("期限の無い目標を達成した");
  }
  return {
    name: "goal_achieved",
    daysFromStart: countDaysBetween(goal.startedOn, achievedOn),
    daysUntilDeadline: countDaysBetween(achievedOn, goal.weightChange.deadlineOn),
  };
};
