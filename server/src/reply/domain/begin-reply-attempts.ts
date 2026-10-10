import { computeNextAttemptAt } from "../../domain/compute-next-attempt-at";
import { createRecordLedger } from "../../domain/create-record-ledger";
import { generateRecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { RecordType } from "../../domain/record-type";
import type { LedgerStore } from "../../domain/sync-ledger/ledger-store";
import type { UsageEvent } from "../../domain/usage-event";
import { computeReplyGenerationEndedEvent } from "./compute-reply-generation-ended-event";
import { maximumDailyReplyGenerations } from "./maximum-daily-reply-generations";
import { maximumReplyAttempts } from "./maximum-reply-attempts";
import { replyAttemptTimeLimitMs } from "./reply-attempt-time-limit-ms";
import type { ReplyGenerationOrigin } from "./reply-store";

// 提供元を呼ぶ前に書いた試み。呼び出し中に止まっても、行が残って試みに数える
export type BegunReplyAttempt = ReplyGenerationOrigin & { attemptId: string };

// アラームから呼ぶ。1つのトランザクションで、待っている依頼から返事の生成を始めて最初の試みを書き、
// 次に試みる時刻が来た続いている生成の試みを書く。途中で止まった試みで上限に達した生成は、もう呼ばずに作れなかったにする。
// 依頼の数える日の生成が1日の上限に達していれば、生成を始めず、提供元を呼ばずに回数切れにする（翌日に回さない）。
// 返す試みは、応える文章の送った順
export const beginReplyAttempts = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  now: Date,
): { attempts: BegunReplyAttempt[]; usageEvents: UsageEvent[] } =>
  createRecordLedger(ledgerStore, stores, now).changeOutsideWrites((addChange) =>
    stores.writeReplyEvents(addChange, (writes) => {
      const attempts: BegunReplyAttempt[] = [];
      const usageEvents: UsageEvent[] = [];
      const beginAttempt = (origin: ReplyGenerationOrigin) => {
        const attemptId = generateRecordId();
        writes.beginAttempt({ id: attemptId, generationId: origin.generationId, attemptedAt: now });
        attempts.push({ ...origin, attemptId });
      };

      // 始めた生成の試みは呼び出し中なので、下の続いている生成では次に試みる時刻がまだ来ていない
      for (const {
        requestId,
        sentText,
        countedOn,
        requestedAt,
      } of stores.reply.findWaitingRequests()) {
        if (stores.reply.countGenerationsCountedOn(countedOn) >= maximumDailyReplyGenerations) {
          writes.halt({ requestId, haltedAt: now });
          usageEvents.push({ name: "reply_request_halted" });
          continue;
        }
        const generationId = generateRecordId();
        writes.beginGeneration({ id: generationId, requestId, startedAt: now });
        beginAttempt({ generationId, sentText, requestedAt });
      }

      for (const { attempts: previous, ...origin } of stores.reply.findContinuingGenerations()) {
        if (computeNextAttemptAt(previous, replyAttemptTimeLimitMs).getTime() > now.getTime()) {
          continue;
        }
        if (previous.length < maximumReplyAttempts) {
          beginAttempt(origin);
          continue;
        }
        writes.abandon({ generationId: origin.generationId, abandonedAt: now });
        usageEvents.push(
          computeReplyGenerationEndedEvent({
            final: { status: "failed" },
            attempts: previous,
            requestedAt: origin.requestedAt,
            endedAt: now,
          }),
        );
      }
      return {
        attempts: attempts.toSorted(
          (a, b) =>
            a.sentText.sentAt.getTime() - b.sentText.sentAt.getTime() ||
            a.sentText.id.localeCompare(b.sentText.id),
        ),
        usageEvents,
      };
    }),
  );
