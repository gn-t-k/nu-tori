import { computeUsageEvents } from "./compute-usage-events";
import { createRecordLedger } from "./create-record-ledger";
import type { RecordKindStores } from "./record-kind-stores";
import type { RecordType } from "./record-type";
import type { SyncChange } from "./sync-change";
import type { SyncClientState } from "./sync-client-state";
import type { LedgerStore } from "./sync-ledger/ledger-store";
import type { UsageEvent } from "./usage-event";

export const pullSyncChanges = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  request: { clientState: SyncClientState; afterSequence: number; receivedAt: Date },
): {
  changes: SyncChange[];
  hasMore: boolean;
  nextAfterSequence: number;
  startedOn: string | undefined;
  usageEvents: UsageEvent[];
} => {
  const pulled = createRecordLedger(ledgerStore, stores).pull(request);
  return {
    changes: pulled.changes,
    hasMore: pulled.hasMore,
    nextAfterSequence: pulled.lastSequence ?? request.afterSequence,
    startedOn: stores.firstSignIn.findStartedOn(),
    usageEvents: computeUsageEvents({
      clientState: request.clientState,
      receivedAt: request.receivedAt,
      previousRequestReceivedAt: pulled.previousRequestReceivedAt,
      sendsUsageData: stores.accountSettings.find()?.sendsUsageData ?? true,
      writeEvents: [],
    }),
  };
};
