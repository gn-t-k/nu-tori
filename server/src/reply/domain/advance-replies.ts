import { match, P } from "ts-pattern";
import { sendsUsageData } from "../../account-settings/domain/sends-usage-data";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import { beginReplyAttempts } from "./begin-reply-attempts";
import type { ConversationProvider } from "./conversation-provider";
import { recordReplyAttemptOutcome } from "./record-reply-attempt-outcome";
import type { ReplyAttemptOutcome } from "./reply-attempt-outcome";
import { runReplyAttempt } from "./run-reply-attempt";

// アラームの返事の入口。待っている依頼から返事の生成を始め（回数切れならそこで止め）、時刻が来た試みを書いてから、
// 応える文章の送った順に1つずつ提供元を呼び、結果を書く。先に作った返事を、あとの文章の文脈の窓に入れるため、並べて呼ばない。
// armAlarm は試みを書いたあと、呼ぶ前に呼ぶ。呼び出し中に止まっても、次に試みる時刻にアラームが動くため。
// 止まった試み（文脈を読めなかったなど）は投げずに返し、ほかの試みの結果を書き終えてから呼び出し側が投げる
export const advanceReplies = async (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  deps: { provider: ConversationProvider; armAlarm: () => Promise<void> },
  now: Date,
): Promise<{
  // 利用状況を送らない人には空
  usageEvents: UsageEvent[];
  // アラームの呼び出しごとのログに出す、試みごとの結果
  attempts: ReplyAttemptReport[];
  // Sentry に包まずに送る、提供元の応答のエラー（提供元のエラーと 400）
  providerErrors: unknown[];
  stoppedError: unknown;
}> => {
  const begun = beginReplyAttempts(ledgerStore, stores, now);
  if (begun.attempts.length > 0) {
    await deps.armAlarm();
  }
  const usageEvents = [...begun.usageEvents];
  const attempts: ReplyAttemptReport[] = [];
  const providerErrors: unknown[] = [];
  let stoppedError: unknown = undefined;
  for (const attempt of begun.attempts) {
    try {
      const outcome = await runReplyAttempt(deps.provider, stores, attempt.sentText);
      usageEvents.push(
        ...recordReplyAttemptOutcome(ledgerStore, stores, attempt, outcome, new Date()),
      );
      attempts.push(toAttemptReport(outcome));
      providerErrors.push(...toProviderErrors(outcome));
    } catch (error) {
      attempts.push({ result: undefined });
      stoppedError ??= error;
    }
  }
  return {
    usageEvents: sendsUsageData(stores.accountSettings) ? usageEvents : [],
    attempts,
    providerErrors,
    stoppedError,
  };
};

type ReplyAttemptReport =
  | { result: "succeeded" | "timed_out" | "invalid_response" }
  | { result: "provider_error" | "bad_request"; errorType: string }
  // 途中で止まった試みは結果が無い
  | { result: undefined };

const toAttemptReport = (outcome: ReplyAttemptOutcome): ReplyAttemptReport =>
  match(outcome)
    .returnType<ReplyAttemptReport>()
    .with({ result: P.union("succeeded", "timed_out", "invalid_response") }, ({ result }) => ({
      result,
    }))
    .with({ result: P.union("provider_error", "bad_request") }, ({ result, errorType }) => ({
      result,
      errorType,
    }))
    .exhaustive();

const toProviderErrors = (outcome: ReplyAttemptOutcome): unknown[] =>
  match(outcome)
    .returnType<unknown[]>()
    .with({ result: P.union("succeeded", "timed_out", "invalid_response") }, () => [])
    .with({ result: P.union("provider_error", "bad_request") }, ({ providerError }) => [
      providerError,
    ])
    .exhaustive();
