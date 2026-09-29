import type { SyncClientState } from "./sync-client-state";
import type { SyncStore } from "./sync-store";
import type { WeightRecord } from "./weight-record";

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
    const found = store.findLatestChangePerRecord(request.afterSequence, changesPerPull + 1);
    const changes = found
      .slice(0, changesPerPull)
      .map(({ sequence, recordType, recordId }): SyncChange =>
        match(recordType)
          .with("weight_record", (): SyncChange => {
            const weightRecord = store.findWeightRecord(recordId);
            if (weightRecord === undefined) {
              throw new Error(`変更の並びが指す体重記録が無い: ${recordId}`);
            }
            return { sequence, type: "weight_record", weightRecord };
          })
          .with("account_settings", (): SyncChange => {
            const accountSettings = store.findAccountSettings();
            if (accountSettings === undefined) {
              throw new Error(`変更の並びが指すアカウントの設定が無い: ${recordId}`);
            }
            return { sequence, type: "account_settings", accountSettings };
          })
          .exhaustive(),
      );
    return {
      changes,
      hasMore: found.length > changesPerPull,
      nextAfterSequence: changes.at(-1)?.sequence ?? request.afterSequence,
      startedOn: store.findStartedOn(),
    };
  });
