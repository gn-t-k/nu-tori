import { R } from "@praha/byethrow";
import { match, P } from "ts-pattern";
import { sendsUsageData } from "../../account-settings/domain/sends-usage-data";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import { beginReplyAttempts } from "./begin-reply-attempts";
import { concludeReplyAttempt } from "./conclude-reply-attempt";
import type { ReplyWatchers } from "./create-reply-watchers";
import type { ConversationProvider } from "./conversation-provider";
import { recordReplyAttemptOutcome } from "./record-reply-attempt-outcome";
import type { ReplyAttemptConclusion } from "./reply-attempt";
import type { ReplyAttemptOutcome } from "./reply-attempt-outcome";
import { runReplyAttempt } from "./run-reply-attempt";

// アラームの返事の入口。待っている依頼から返事の生成を始め（回数切れならそこで止め）、時刻が来た試みを書いてから、
// 応える文章の送った順に1つずつ提供元を呼び、結果を書く。先に作った返事を、あとの文章の文脈の窓に入れるため、並べて呼ばない。
// armAlarm は試みを書いたあと、呼ぶ前に呼ぶ。呼び出し中に止まっても、次に試みる時刻にアラームが動くため。
// 止まった試み（文脈を読めなかったなど）は投げずに返し、ほかの試みの結果を書き終えてから呼び出し側が投げる。
// 見守る要求には、生成を始めたら返事の ID を、呼んでいるあいだはできた分を、結果を書いたら返事か作れなかったを送る
export const advanceReplies = async (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  deps: { provider: ConversationProvider; armAlarm: () => Promise<void>; watchers: ReplyWatchers },
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
  deps.watchers.refresh(stores);
  if (begun.attempts.length > 0) {
    await deps.armAlarm();
  }
  const usageEvents = [...begun.usageEvents];
  const attempts: ReplyAttemptReport[] = [];
  const providerErrors: unknown[] = [];
  let stoppedError: unknown = undefined;
  for (const attempt of begun.attempts) {
    const sentTextId = attempt.sentText.id;
    try {
      await R.pipe(
        runReplyAttempt(deps.provider, stores, attempt.sentText, (text) =>
          deps.watchers.appendText(sentTextId, text),
        ),
        // 通らなかった試みも結果として書く
        R.orElse((failed) => R.succeed<ReplyAttemptOutcome>(failed)),
        R.inspect((outcome) => {
          deps.watchers.endAttempt(sentTextId, outcome.result === "succeeded");
          usageEvents.push(
            ...recordReplyAttemptOutcome(ledgerStore, stores, attempt, outcome, new Date()),
          );
          deps.watchers.refresh(stores);
          attempts.push(concludeReplyAttempt(outcome));
          providerErrors.push(...toProviderErrors(outcome));
        }),
      );
    } catch (error) {
      deps.watchers.endAttempt(sentTextId, false);
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

// 途中で止まった試みは結果が無い
type ReplyAttemptReport = ReplyAttemptConclusion | { result: undefined };

const toProviderErrors = (outcome: ReplyAttemptOutcome): unknown[] =>
  match(outcome)
    .returnType<unknown[]>()
    .with({ result: P.union("succeeded", "timed_out", "invalid_response") }, () => [])
    .with({ result: P.union("provider_error", "bad_request") }, ({ providerError }) => [
      providerError,
    ])
    .exhaustive();
