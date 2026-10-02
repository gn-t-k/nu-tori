import { createRecordLedger } from "../../domain/create-record-ledger";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import type { Meal } from "../../meal/domain/meal";
import { computeEstimationEndedEvent } from "./compute-estimation-ended-event";
import { computeNextDayStart } from "./compute-next-day-start";
import { computeNextEstimationAttemptAt } from "./compute-next-estimation-attempt-at";
import { findLatestValidTimeZone } from "./find-latest-valid-time-zone";
import { findMealReceivedAt } from "./find-meal-received-at";
import { maximumDailyEstimations } from "./maximum-daily-estimations";
import { maximumEstimationAttempts } from "./maximum-estimation-attempts";

// 提供元を呼ぶ前に書いた試み。呼び出し中に止まっても、行が残って試みに数える
export type BegunEstimationAttempt = {
  attemptId: string;
  estimationId: string;
  photoIds: readonly string[];
};

// アラームから呼ぶ。1つのトランザクションで、時刻が来た待っている予定から推定を始めて最初の試みを書き、
// 次に試みる時刻が来た続いている推定の試みを書く。途中で止まった試みで上限に達した推定は、もう呼ばずに諦める。
// 予定の数える日の推定が1日の上限に達していれば、推定を始めず、次の日の 0:00 の予定を足して見送る
export const beginEstimationAttempts = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  now: Date,
): { attempts: BegunEstimationAttempt[]; usageEvents: UsageEvent[] } =>
  createRecordLedger(ledgerStore, stores, now).changeOutsideWrites((addChange) =>
    stores.writeEstimationEvents(addChange, (writes) => {
      const attempts: BegunEstimationAttempt[] = [];
      const usageEvents: UsageEvent[] = [];
      const beginAttempt = (estimationId: string, mealId: string) => {
        const meal = findScheduledMeal(stores, mealId);
        const attemptId = crypto.randomUUID();
        writes.beginAttempt({ id: attemptId, estimationId, attemptedAt: now });
        attempts.push({ attemptId, estimationId, photoIds: meal.photoIds });
      };

      // 始めた推定の試みは呼び出し中なので、下の続いている推定では次に試みる時刻がまだ来ていない
      for (const {
        scheduleId,
        mealId,
        countedOn,
      } of stores.estimationSchedule.findDueWaitingSchedules(now)) {
        if (stores.estimation.countEstimationsCountedOn(countedOn) >= maximumDailyEstimations) {
          const nextDay = computeNextDayStart(
            countedOn,
            findLatestValidTimeZone(stores.estimationSchedule) ??
              findScheduledMeal(stores, mealId).sentTimeZone,
          );
          writes.deferToNextDay({
            scheduleId,
            mealId,
            deferredAt: now,
            nextSchedule: {
              id: crypto.randomUUID(),
              dueAt: nextDay.startsAt,
              countedOn: nextDay.countedOn,
            },
          });
          usageEvents.push({ name: "estimation_deferred" });
          continue;
        }
        const estimationId = crypto.randomUUID();
        writes.beginEstimation({ id: estimationId, scheduleId, mealId, startedAt: now });
        beginAttempt(estimationId, mealId);
      }

      for (const {
        estimationId,
        mealId,
        attempts: previous,
      } of stores.estimation.findContinuingEstimations()) {
        if (computeNextEstimationAttemptAt(previous).getTime() > now.getTime()) {
          continue;
        }
        if (previous.length < maximumEstimationAttempts) {
          beginAttempt(estimationId, mealId);
          continue;
        }
        writes.abandon({ estimationId, mealId, abandonedAt: now });
        usageEvents.push(
          computeEstimationEndedEvent({
            finalStatus: "failed",
            attempts: previous,
            receivedAt: findMealReceivedAt(stores.estimationSchedule, mealId),
            endedAt: now,
            dishCount: 0,
            ingredients: [],
          }),
        );
      }
      return { attempts, usageEvents };
    }),
  );

const findScheduledMeal = (stores: Pick<RecordKindStores, "meal">, mealId: string): Meal => {
  const meal = stores.meal.find(mealId);
  if (meal === undefined) {
    throw new Error(`推定の予定につながっている食事が無い: ${mealId}`);
  }
  return meal;
};
