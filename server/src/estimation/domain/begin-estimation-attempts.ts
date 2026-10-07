import { match } from "ts-pattern";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import { createRecordLedger } from "../../domain/create-record-ledger";
import { findLatestValidTimeZone } from "../../domain/find-latest-valid-time-zone";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import type { Meal } from "../../meal/domain/meal";
import { abandonEstimation } from "./abandon-estimation";
import { computeDishToReestimate } from "./compute-dish-to-reestimate";
import { computeEstimationEndedEvent } from "./compute-estimation-ended-event";
import { computeNextDayStart } from "./compute-next-day-start";
import { computeNextEstimationAttemptAt } from "./compute-next-estimation-attempt-at";
import type { IdentificationTarget } from "./estimation-provider";
import type { EstimationTarget } from "./estimation-target";
import { findEstimationOrigin } from "./find-estimation-origin";
import { maximumDailyEstimations } from "./maximum-daily-estimations";
import { maximumEstimationAttempts } from "./maximum-estimation-attempts";

// 提供元を呼ぶ前に書いた試み。呼び出し中に止まっても、行が残って試みに数える。
// 料理が対象の推定（推定し直し）は、試みを書いた時点の料理の今の値を ① に渡す
export type BegunEstimationAttempt = {
  attemptId: string;
  estimationId: string;
  photoIds: readonly RecordId[];
  target: IdentificationTarget;
};

// アラームから呼ぶ。1つのトランザクションで、時刻が来た待っている予定（食事か料理が対象）から推定を始めて最初の試みを書き、
// 次に試みる時刻が来た続いている推定の試みを書く。途中で止まった試みで上限に達した推定は、もう呼ばずに諦める。
// 予定の数える日の推定が1日の上限に達していれば、推定を始めず、次の日の 0:00 の予定を同じ対象に足して見送る
export const beginEstimationAttempts = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  now: Date,
): { attempts: BegunEstimationAttempt[]; usageEvents: UsageEvent[] } =>
  createRecordLedger(ledgerStore, stores, now).changeOutsideWrites((addChange) =>
    stores.writeEstimationEvents(addChange, now, (writes) => {
      const attempts: BegunEstimationAttempt[] = [];
      const usageEvents: UsageEvent[] = [];
      const beginAttempt = (estimationId: string, target: EstimationTarget) => {
        const meal = findScheduledMeal(stores, target.mealId);
        const attemptId = generateRecordId();
        writes.beginAttempt({ id: attemptId, estimationId, attemptedAt: now });
        attempts.push({
          attemptId,
          estimationId,
          photoIds: meal.photoIds,
          target: match(target)
            .returnType<IdentificationTarget>()
            .with({ type: "meal" }, () => ({ type: "meal" }))
            .with({ type: "dish" }, ({ dishId }) => ({
              type: "dish",
              dish: computeDishToReestimate(stores, dishId),
            }))
            .exhaustive(),
        });
      };

      // 始めた推定の試みは呼び出し中なので、下の続いている推定では次に試みる時刻がまだ来ていない
      for (const {
        scheduleId,
        target,
        countedOn,
      } of stores.estimationSchedule.findWaitingSchedules(now)) {
        if (stores.estimation.countEstimationsCountedOn(countedOn) >= maximumDailyEstimations) {
          const nextDay = computeNextDayStart(
            countedOn,
            findLatestValidTimeZone(stores.latestTimeZone) ??
              findScheduledMeal(stores, target.mealId).sentTimeZone,
          );
          writes.deferToNextDay({
            scheduleId,
            target,
            deferredAt: now,
            nextSchedule: {
              id: generateRecordId(),
              dueAt: nextDay.startsAt,
              countedOn: nextDay.countedOn,
            },
          });
          usageEvents.push({ name: "estimation_deferred" });
          continue;
        }
        const estimationId = generateRecordId();
        writes.beginEstimation({ id: estimationId, scheduleId, target, startedAt: now });
        beginAttempt(estimationId, target);
      }

      for (const {
        estimationId,
        target,
        attempts: previous,
      } of stores.estimation.findContinuingEstimations()) {
        if (computeNextEstimationAttemptAt(previous).getTime() > now.getTime()) {
          continue;
        }
        if (previous.length < maximumEstimationAttempts) {
          beginAttempt(estimationId, target);
          continue;
        }
        abandonEstimation(stores, writes, addChange, { estimationId, target, abandonedAt: now });
        usageEvents.push(
          computeEstimationEndedEvent({
            ...findEstimationOrigin(stores, target, estimationId),
            finalStatus: "failed",
            attempts: previous,
            endedAt: now,
            dishCount: 0,
            ingredients: [],
          }),
        );
      }
      return { attempts, usageEvents };
    }),
  );

const findScheduledMeal = (stores: Pick<RecordKindStores, "meal">, mealId: RecordId): Meal => {
  const meal = stores.meal.find(mealId);
  if (meal === undefined) {
    throw new Error(`推定の予定につながっている食事が無い: ${mealId}`);
  }
  return meal;
};
