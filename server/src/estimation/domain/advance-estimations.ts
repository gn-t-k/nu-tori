import { sendsUsageData } from "../../account-settings/domain/sends-usage-data";
import { match, P } from "ts-pattern";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import type { MealPhotoArchive } from "../../meal/domain/meal-photo-archive";
import { beginEstimationAttempts } from "./begin-estimation-attempts";
import type { EstimationAttemptOutcome } from "./estimation-attempt-outcome";
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
  // Sentry に包まずに送る、提供元の応答のエラー（提供元のエラーと 400）
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
  const usageEvents = [
    ...begun.usageEvents,
    ...settled.flatMap((attempt) =>
      attempt.status === "fulfilled" ? attempt.value.usageEvents : [],
    ),
  ];
  return {
    usageEvents: sendsUsageData(stores.accountSettings) ? usageEvents : [],
    attempts: settled.map(toAttemptReport),
    providerErrors: settled.flatMap((attempt) =>
      attempt.status === "fulfilled" && "providerError" in attempt.value.outcome
        ? [attempt.value.outcome.providerError]
        : [],
    ),
    stoppedError: settled.find((attempt) => attempt.status === "rejected")?.reason,
  };
};

type AttemptReport =
  | { result: "succeeded" }
  | {
      result: "timed_out" | "invalid_response";
      failedStage: "identify_dishes" | "match_ingredients";
    }
  | {
      result: "provider_error" | "bad_request";
      failedStage: "identify_dishes" | "match_ingredients";
      errorType: string;
    }
  // 途中で止まった試みは結果が無い
  | { result: undefined; failedStage: string | undefined };

const toAttemptReport = (
  settled: PromiseSettledResult<{ outcome: EstimationAttemptOutcome }>,
): AttemptReport => {
  if (settled.status === "rejected") {
    const reason: unknown = settled.reason;
    return {
      result: undefined,
      failedStage:
        reason instanceof Error && "stage" in reason && typeof reason.stage === "string"
          ? reason.stage
          : undefined,
    };
  }
  return match(settled.value.outcome)
    .returnType<AttemptReport>()
    .with({ result: "succeeded" }, ({ result }) => ({ result }))
    .with({ result: P.union("timed_out", "invalid_response") }, ({ result, failedStage }) => ({
      result,
      failedStage,
    }))
    .with(
      { result: P.union("provider_error", "bad_request") },
      ({ result, failedStage, errorType }) => ({ result, failedStage, errorType }),
    )
    .exhaustive();
};
