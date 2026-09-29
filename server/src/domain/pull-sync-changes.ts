import { match } from "ts-pattern";
import { computeUsageEvents } from "./compute-usage-events";
import type { SyncChange } from "./sync-change";
import type { SyncClientState } from "./sync-client-state";
import type { SyncStore } from "./sync-store";
import type { UsageEvent } from "./usage-event";

export const pullSyncChanges = (
  store: SyncStore,
  request: { clientState: SyncClientState; afterSequence: number; receivedAt: Date },
): {
  changes: SyncChange[];
  hasMore: boolean;
  nextAfterSequence: number;
  startedOn: string | undefined;
  usageEvents: UsageEvent[];
} =>
  store.transaction(() => {
    const changesPerPull = 500;
    const previousRequestReceivedAt = store.findLatestRequestReceivedAt();
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
      usageEvents: computeUsageEvents(store, {
        clientState: request.clientState,
        receivedAt: request.receivedAt,
        previousRequestReceivedAt,
        rejectedWrites: [],
      }),
    };
  });
