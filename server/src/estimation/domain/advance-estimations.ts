import { R } from "@praha/byethrow";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import type { MealPhotoArchive } from "../../meal/domain/meal-photo-archive";
import { beginEstimationAttempts } from "./begin-estimation-attempts";
import type { EstimationAttemptResult } from "./estimation-attempt-result";
import type { EstimationProvider } from "./estimation-provider";
import { recordEstimationAttemptOutcome } from "./record-estimation-attempt-outcome";
import { runEstimationAttempt } from "./run-estimation-attempt";

// アラームの推定の入口。予定から推定を始め、時刻が来た試みを書いてから、提供元を並べて呼び、結果を書く。
// armAlarm は試みを書いたあと、呼ぶ前に呼ぶ。呼び出し中に止まっても、次に試みる時刻にアラームが動くため。
// 止まった試み（R2・成分表の段）は投げずに返し、ほかの試みの結果を書き終えてから呼び出し側が投げる
export const advanceEstimations = async (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  deps: {
    archive: MealPhotoArchive;
    provider: EstimationProvider;
    armAlarm: () => Promise<void>;
  },
  now: Date,
): Promise<{
  // 利用状況を送らない人には空
  usageEvents: UsageEvent[];
  // アラームの呼び出しごとのログに出す、試みごとの結果と失敗した段
  attempts: AttemptReport[];
  // Sentry に送る、提供元が返したエラー（提供元のエラーと 400）
  providerErrors: unknown[];
  stoppedError: unknown;
}> => {
  const begun = beginEstimationAttempts(ledgerStore, stores, now);
  if (begun.attempts.length > 0) {
    await deps.armAlarm();
  }
  const settled = await Promise.allSettled(
    begun.attempts.map(async (attempt) => {
      const outcome = await runEstimationAttempt(deps, attempt.photoIds);
      return {
        outcome,
        usageEvents: recordEstimationAttemptOutcome(
          ledgerStore,
          stores,
          attempt,
          outcome,
          new Date(),
        ),
      };
    }),
  );
  const sendsUsageData = stores.accountSettings.find()?.sendsUsageData ?? true;
  const usageEvents = [
    ...begun.usageEvents,
    ...settled.flatMap((attempt) =>
      attempt.status === "fulfilled" ? attempt.value.usageEvents : [],
    ),
  ];
  return {
    usageEvents: sendsUsageData ? usageEvents : [],
    attempts: settled.map(toAttemptReport),
    providerErrors: settled.flatMap((attempt) =>
      attempt.status === "fulfilled" &&
      R.isFailure(attempt.value.outcome) &&
      attempt.value.outcome.error.errorType !== undefined
        ? [attempt.value.outcome.error.cause]
        : [],
    ),
    stoppedError: settled.find((attempt) => attempt.status === "rejected")?.reason,
  };
};

type AttemptReport = {
  // 途中で止まった試みは undefined
  result: EstimationAttemptResult | undefined;
  failedStage: string | undefined;
  providerErrorType: string | undefined;
};

const toAttemptReport = (
  settled: PromiseSettledResult<{
    outcome: Awaited<ReturnType<typeof runEstimationAttempt>>;
  }>,
): AttemptReport => {
  if (settled.status === "rejected") {
    const reason: unknown = settled.reason;
    return {
      result: undefined,
      failedStage:
        reason instanceof Error && "stage" in reason && typeof reason.stage === "string"
          ? reason.stage
          : undefined,
      providerErrorType: undefined,
    };
  }
  const { outcome } = settled.value;
  return R.isSuccess(outcome)
    ? { result: "succeeded", failedStage: undefined, providerErrorType: undefined }
    : {
        result: outcome.error.result,
        failedStage: outcome.error.failedStage,
        providerErrorType: outcome.error.errorType,
      };
};
