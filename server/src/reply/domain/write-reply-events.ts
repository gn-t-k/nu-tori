import type { RecordId } from "../../domain/record-id";
import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import type { SentTextStore } from "../../sent-text/domain/sent-text-store";
import { createSentTextStatusKind } from "../../sent-text-status/domain/create-sent-text-status-kind";
import type { SentTextStatus } from "../../sent-text-status/domain/sent-text-status";
import type { SentTextStatusStore } from "../../sent-text-status/domain/sent-text-status-store";
import type { ReplyEventWriteStore } from "./reply-event-write-store";
import type { ReplyWrites } from "./reply-writes";

// 返事の書き込みの口。返事の流れの出来事は、ここを通して書く。
// 表で守らない決まり（依頼は会話の文章にだけ、回数切れと生成はどちらか1つ、返事と作れなかったはどちらか1つ。設計判断 34・40）を
// 書く前に確かめ、破る書き込みは投げる。きっかけがちょうど1つなことは、依頼の型（trigger）で守る。
// 書いた送った文章ごとに、初めて書く前と run のあとの送った文章の状態を比べ、違う文章にだけ、書いた順に状態の変更を足す。
// 返事を書いたら、返事の変更も足す。addChange は帳簿の changeOutsideWrites か、書き込みの決定の commit に渡るもの
export const writeReplyEvents = <T>(
  stores: {
    sentText: SentTextStore;
    sentTextStatus: SentTextStatusStore;
    replyEventWrite: ReplyEventWriteStore;
  },
  addChange: (change: RecordChangeTarget<"sent_text_status" | "ai_utterance">) => void,
  run: (writes: ReplyWrites) => T,
): T => {
  const statusKind = createSentTextStatusKind(stores.sentText, stores.sentTextStatus);
  const store = stores.replyEventWrite;
  const statusesBeforeWrites = new Map<RecordId, CurrentRecord<SentTextStatus>>();
  const remember = (sentTextId: RecordId | undefined): void => {
    if (sentTextId === undefined) {
      throw new Error("返事の流れの出来事が、送った文章につながっていない");
    }
    if (!statusesBeforeWrites.has(sentTextId)) {
      statusesBeforeWrites.set(sentTextId, statusKind.readCurrent(sentTextId));
    }
  };

  const result = run({
    request: (request) => {
      if (stores.sentTextStatus.findClassification(request.sentTextId) !== "conversation") {
        throw new Error(
          `会話と読み分けていない文章に返事の依頼を書こうとした: ${request.sentTextId}`,
        );
      }
      remember(request.sentTextId);
      store.insertRequest(request);
    },
    halt: (halt) => {
      if (store.hasGeneration(halt.requestId)) {
        throw new Error(`生成を始めた依頼を回数切れにしようとした: ${halt.requestId}`);
      }
      remember(store.findSentTextIdOfRequest(halt.requestId));
      store.insertHalt(halt);
    },
    beginGeneration: (generation) => {
      if (store.hasHalt(generation.requestId)) {
        throw new Error(`回数切れの依頼の生成を始めようとした: ${generation.requestId}`);
      }
      remember(store.findSentTextIdOfRequest(generation.requestId));
      store.insertGeneration(generation);
    },
    beginAttempt: (attempt) => {
      store.insertAttempt(attempt);
    },
    recordAttemptResult: (attemptResult) => {
      store.insertAttemptResult(attemptResult);
    },
    reply: (reply) => {
      if (store.hasAbandonment(reply.generationId)) {
        throw new Error(`作れなかった生成に返事を書こうとした: ${reply.generationId}`);
      }
      remember(store.findSentTextIdOfGeneration(reply.generationId));
      store.insertUtterance(reply);
      addChange({ recordType: "ai_utterance", recordId: reply.generationId });
    },
    abandon: (abandonment) => {
      if (store.hasUtterance(abandonment.generationId)) {
        throw new Error(
          `返事を書いた生成を作れなかったにしようとした: ${abandonment.generationId}`,
        );
      }
      remember(store.findSentTextIdOfGeneration(abandonment.generationId));
      store.insertAbandonment(abandonment);
    },
  });

  for (const [sentTextId, before] of statusesBeforeWrites) {
    if (!isSameStatus(before, statusKind.readCurrent(sentTextId))) {
      addChange({ recordType: "sent_text_status", recordId: sentTextId });
    }
  }
  return result;
};

const isSameStatus = (
  a: CurrentRecord<SentTextStatus>,
  b: CurrentRecord<SentTextStatus>,
): boolean =>
  a.status === "value" && b.status === "value"
    ? JSON.stringify(a.value) === JSON.stringify(b.value)
    : a.status === b.status;
