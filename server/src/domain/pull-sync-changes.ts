import type { SyncChange } from "./sync-change";
import type { SyncClientState } from "./sync-client-state";
import type { SyncStore } from "./sync-store";

export const pullSyncChanges = (
  store: SyncStore,
  request: { clientState: SyncClientState; afterSequence: number; receivedAt: Date },
): {
  changes: SyncChange[];
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
    const found = store.findLatestChangePerRecord(request.afterSequence, changesPerPull + 1);
    const changes = found.slice(0, changesPerPull).map(({ sequence, recordId }): SyncChange => {
      const weightRecord = store.findWeightRecord(recordId);
      if (weightRecord !== undefined) {
        return { sequence, type: "weight_record", weightRecord };
      }
      if (store.existsWeightRecordDeletion(recordId)) {
        return { sequence, type: "weight_record_deletion", recordId };
      }
      throw new Error(`変更の並びが指す体重記録も削除の印も無い: ${recordId}`);
    });
    return {
      changes,
      hasMore: found.length > changesPerPull,
      nextAfterSequence: changes.at(-1)?.sequence ?? request.afterSequence,
      startedOn: store.findStartedOn(),
    };
  });
