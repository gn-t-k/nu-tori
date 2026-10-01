import { computeUsageEvents } from "./compute-usage-events";
import { createRecordLedger } from "./create-record-ledger";
import type { RecordKindStores } from "./record-kind-stores";
import type { RecordType } from "./record-type";
import type { SyncClientState } from "./sync-client-state";
import type { LedgerStore } from "./sync-ledger/ledger-store";
import type { PushedResult } from "./sync-ledger/pushed-result";
import type { SyncWrite } from "./sync-write";
import type { UsageEvent } from "./usage-event";

export const applySyncWrites = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  request: {
    clientState: SyncClientState;
    writes: readonly SyncWrite[];
    isFinalBatch: boolean;
    receivedAt: Date;
  },
): {
  results: PushedResult<RecordType, unknown>[];
  usageEvents: UsageEvent[];
} => {
  const pushed = createRecordLedger(ledgerStore, stores).push(request);
  return {
    results: pushed.results,
    usageEvents: computeUsageEvents({
      clientState: request.clientState,
      receivedAt: request.receivedAt,
      previousRequestReceivedAt: pushed.previousRequestReceivedAt,
      sendsUsageData: stores.accountSettings.find()?.sendsUsageData ?? true,
      rejectedWrites: pushed.rejectedWrites.map((rejected) => ({
        name: "sync_write_rejected",
        ...rejected,
      })),
    }),
  };
};
