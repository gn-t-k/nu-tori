import { match } from "ts-pattern";
import { createRecordLedger } from "../../domain/create-record-ledger";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import type { BegunReplyAttempt } from "./begin-reply-attempts";
import { computeReplyGenerationEndedEvent } from "./compute-reply-generation-ended-event";
import { maximumReplyAttempts } from "./maximum-reply-attempts";
import type { ReplyAttemptConclusion } from "./reply-attempt";
import type { ReplyAttemptOutcome } from "./reply-attempt-outcome";

// 呼び出しから戻ったときに、1つのトランザクションで試みの結果を書く。
// 通ったら返事と指し示す食事を書く。400 か、試みが上限に達したら作れなかったにする。
// 呼び出し中にほかで終わっていたら（途中で止まった試みとみなして作れなかったにした）、結果だけを書く。
// 返すのは PostHog に送る出来事
export const recordReplyAttemptOutcome = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  attempt: BegunReplyAttempt,
  outcome: ReplyAttemptOutcome,
  endedAt: Date,
): UsageEvent[] =>
  createRecordLedger(ledgerStore, stores, endedAt).changeOutsideWrites((addChange) =>
    stores.writeReplyEvents(addChange, (writes) => {
      const { generationId } = attempt;
      writes.recordAttemptResult({
        attemptId: attempt.attemptId,
        endedAt,
        conclusion: toConclusion(outcome),
      });
      const attemptEnded: UsageEvent = {
        name: "reply_attempt_ended",
        result: outcome.result,
        usage: outcome.usage,
        providerErrorType:
          outcome.result === "provider_error" || outcome.result === "bad_request"
            ? outcome.errorType
            : undefined,
      };
      if (stores.reply.hasEnded(generationId)) {
        return [attemptEnded];
      }
      const attempts = stores.reply.findAttempts(generationId);
      const ended = { attempts, requestedAt: attempt.requestedAt, endedAt };
      if (outcome.result === "succeeded") {
        writes.reply({ generationId, body: outcome.body, mealIds: outcome.mealIds });
        return [
          attemptEnded,
          computeReplyGenerationEndedEvent({
            ...ended,
            final: { status: "replied", referencedMealCount: outcome.mealIds.length },
          }),
        ];
      }
      if (outcome.result === "bad_request" || attempts.length >= maximumReplyAttempts) {
        writes.abandon({ generationId, abandonedAt: endedAt });
        return [
          attemptEnded,
          computeReplyGenerationEndedEvent({ ...ended, final: { status: "failed" } }),
        ];
      }
      return [attemptEnded];
    }),
  );

const toConclusion = (outcome: ReplyAttemptOutcome): ReplyAttemptConclusion =>
  match(outcome)
    .returnType<ReplyAttemptConclusion>()
    .with(
      { result: "succeeded" },
      { result: "timed_out" },
      { result: "invalid_response" },
      ({ result }) => ({
        result,
      }),
    )
    .with({ result: "provider_error" }, { result: "bad_request" }, ({ result, errorType }) => ({
      result,
      errorType,
    }))
    .exhaustive();
