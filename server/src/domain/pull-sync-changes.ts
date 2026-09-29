import type { SyncClientState } from "./sync-client-state";
import type { SyncStore } from "./sync-store";
import type { WeightRecord } from "./weight-record";

// 前回の続きからの変更を、記録ごとにまとめて古い順に返す。1回の応答は 500 件で切り、続きがあるかを添える
export const pullSyncChanges = (
  store: SyncStore,
  request: { clientState: SyncClientState; afterSequence: number; receivedAt: Date },
): {
  changes: { sequence: number; weightRecord: WeightRecord }[];
  hasMore: boolean;
  nextAfterSequence: number;
  startedOn: string | undefined;
} =>
  store.transaction(() => {
    const changesPerPull = 500;
    store.insertPullRequestLog({
      id: crypto.randomUUID(),
      receivedAt: request.receivedAt,
      clientState: request.clientState,
      afterSequence: request.afterSequence,
    });
    const found = store.findRecordChanges(request.afterSequence, changesPerPull + 1);
    const changes = found.slice(0, changesPerPull).map(({ sequence, recordId }) => {
      const weightRecord = store.findWeightRecord(recordId);
      if (weightRecord === undefined) {
        throw new Error(`変更の並びが指す体重記録が無い: ${recordId}`);
      }
      return { sequence, weightRecord };
    });
    return {
      changes,
      hasMore: found.length > changesPerPull,
      nextAfterSequence: changes.at(-1)?.sequence ?? request.afterSequence,
      startedOn: store.findStartedOn(),
    };
  });
