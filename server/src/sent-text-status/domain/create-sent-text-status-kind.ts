import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { SentTextStore } from "../../sent-text/domain/sent-text-store";
import { computeSentTextReplyStatus } from "./compute-sent-text-reply-status";
import type { SentTextStatus } from "./sent-text-status";
import type { SentTextStatusStore } from "./sent-text-status-store";

// 送った文章の状態の種類。サーバーだけが書く。記録の ID は送った文章の ID で、送った文章と同じく消えない
export const createSentTextStatusKind = (
  sentTextStore: SentTextStore,
  store: SentTextStatusStore,
): RecordKind<"sent_text_status", never, SentTextStatus> => ({
  name: "sent_text_status",
  writes: undefined,
  follows: undefined,
  whenGone: "never",
  readCurrent: (sentTextId): CurrentRecord<SentTextStatus> => {
    if (sentTextStore.find(sentTextId) === undefined) {
      return { status: "absent" };
    }
    return {
      status: "value",
      value: {
        classification: store.findClassification(sentTextId) ?? "pending",
        reply: computeSentTextReplyStatus(store.findReplyRequestProgresses(sentTextId)),
      },
    };
  },
});
