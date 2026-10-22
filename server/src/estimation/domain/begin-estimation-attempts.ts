import { match } from "ts-pattern";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import { findLatestValidTimeZone } from "../../domain/find-latest-valid-time-zone";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { UsageEvent } from "../../domain/usage-event";
import type { Meal } from "../../meal/domain/meal";
import type { SentText } from "../../sent-text/domain/sent-text";
import { isSubscriptionExpired } from "../../subscription-status/domain/is-subscription-expired";
import { readSubscriptionStatus } from "../../subscription-status/domain/read-subscription-status";
import type { SubscriptionStatus } from "../../subscription-status/domain/subscription-status";
import { abandonEstimation } from "./abandon-estimation";
import { computeDishToReestimate } from "./compute-dish-to-reestimate";
import { computeNextDayStart } from "./compute-next-day-start";
import { computeNextEstimationAttemptAt } from "./compute-next-estimation-attempt-at";
import type { IdentificationTarget } from "./estimation-provider";
import type { EstimationTarget } from "./estimation-target";
import { maximumDailyEstimations } from "./maximum-daily-estimations";
import { maximumEstimationAttempts } from "./maximum-estimation-attempts";
import { resumeHeldEstimations } from "./resume-held-estimations";

// 提供元を呼ぶ前に書いた試み。呼び出し中に止まっても、行が残って試みに数える。
// 料理が対象の推定（推定し直し）は、試みを書いた時点の料理の今の値を ① に渡す。
// 文章の食事が対象の推定は、写真の代わりに作った送った文章を ① に渡す
export type BegunEstimationAttempt = {
  attemptId: string;
  estimationId: string;
  photoIds: readonly RecordId[];
  target: IdentificationTarget | WrittenMealTarget;
};

// 文章の食事の推定の ① に渡す、作った送った文章（#419 の「文章の食事」）
export type WrittenMealTarget = {
  type: "written_meal";
  sentText: Pick<SentText, "body" | "sentAt" | "timeZone">;
};

// アラームから呼ぶ。1つのトランザクションで、時刻が来た待っている予定（食事か料理が対象）から推定を始めて最初の試みを書き、
// 次に試みる時刻が来た続いている推定の試みを書く。途中で止まった試みで上限に達した推定は、もう呼ばずに諦める。
// 予定の数える日の推定が1日の上限に達していれば、推定を始めず、次の日の 0:00 の予定を同じ対象に足して見送る。
// 予定の数える日でサブスクリプション切れなら、推定を始めず保留する。使えるようになっていれば（テストユーザーの旗を立てたなど）、
// 待っている予定を探す前に、保留した推定を再開する
export const beginEstimationAttempts = (
  writeRecordChanges: RecordChangeWriter,
  stores: Pick<
    RecordKindStores,
    | "dish"
    | "estimation"
    | "estimationSchedule"
    | "ingredient"
    | "latestTimeZone"
    | "meal"
    | "sentText"
    | "subscriptionStatus"
  >,
  now: Date,
): { attempts: BegunEstimationAttempt[]; usageEvents: UsageEvent[] } =>
  writeRecordChanges(({ addChange, estimationAt }) => {
    const writes = estimationAt(now);
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
          .returnType<BegunEstimationAttempt["target"]>()
          .with({ type: "meal" }, () =>
            meal.sentTextId === undefined
              ? { type: "meal" }
              : { type: "written_meal", sentText: findSentText(stores, meal.sentTextId) },
          )
          .with({ type: "dish" }, ({ dishId }) => ({
            type: "dish",
            dish: computeDishToReestimate(stores, dishId),
          }))
          .exhaustive(),
      });
    };

    resumeHeldEstimations(stores, writes, now);
    // 待っている予定があるときだけ読む（最初のサインインより前のアカウントのアラームでも、予定が無ければ読まない）
    let subscriptionStatus: SubscriptionStatus | undefined;
    // 始めた推定の試みは呼び出し中なので、下の続いている推定では次に試みる時刻がまだ来ていない
    for (const { scheduleId, target, countedOn } of stores.estimationSchedule.findWaitingSchedules(
      now,
    )) {
      subscriptionStatus ??= readSubscriptionStatus(stores.subscriptionStatus);
      if (isSubscriptionExpired(subscriptionStatus, { countedOn, at: now })) {
        writes.hold({ scheduleId, target, heldAt: now });
        usageEvents.push({ name: "estimation_deferred", reason: "subscription_expired" });
        continue;
      }
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
        usageEvents.push({ name: "estimation_deferred", reason: "daily_limit" });
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
      usageEvents.push(
        abandonEstimation(stores, writes, addChange, { estimationId, target, abandonedAt: now }),
      );
    }
    return { attempts, usageEvents };
  });

const findScheduledMeal = (stores: Pick<RecordKindStores, "meal">, mealId: RecordId): Meal => {
  const meal = stores.meal.find(mealId);
  if (meal === undefined) {
    throw new Error(`推定の予定につながっている食事が無い: ${mealId}`);
  }
  return meal;
};

const findSentText = (
  stores: Pick<RecordKindStores, "sentText">,
  sentTextId: RecordId,
): SentText => {
  const sentText = stores.sentText.find(sentTextId);
  if (sentText === undefined) {
    throw new Error(`文章の食事を作った送った文章が無い: ${sentTextId}`);
  }
  return sentText;
};
