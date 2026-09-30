import { match } from "ts-pattern";
import type { createRecordKinds } from "./create-record-kinds";
import { computeUsageEvents } from "./compute-usage-events";
import type { RecordType } from "./record-type";
import type { RegisteredRecordType } from "./sync-change";
import type { LegacySyncChange, SyncChange } from "./sync-change";
import type { SyncClientState } from "./sync-client-state";
import { createSyncLedger } from "./sync-ledger/sync-ledger";
import type { SyncStore } from "./sync-store";
import type { SyncWrite } from "./sync-write";
import type { UsageEvent } from "./usage-event";

export const pullSyncChanges = (
  store: SyncStore,
  kinds: ReturnType<typeof createRecordKinds>,
  request: { clientState: SyncClientState; afterSequence: number; receivedAt: Date },
): {
  changes: SyncChange[];
  hasMore: boolean;
  nextAfterSequence: number;
  startedOn: string | undefined;
  usageEvents: UsageEvent[];
} => {
  const ledger = createSyncLedger<RecordType, RegisteredRecordType, SyncWrite, unknown>(
    store,
    kinds,
  );
  const pulled = ledger.pull(request, ({ sequence, recordType, recordId }) =>
    pullLegacyChange(store, { sequence, recordType, recordId }),
  );
  return {
    changes: pulled.changes,
    hasMore: pulled.hasMore,
    nextAfterSequence: pulled.lastSequence ?? request.afterSequence,
    startedOn: store.findStartedOn(),
    usageEvents: computeUsageEvents(store, {
      clientState: request.clientState,
      receivedAt: request.receivedAt,
      previousRequestReceivedAt: pulled.previousRequestReceivedAt,
      rejectedWrites: [],
    }),
  };
};

// 登録簿にない種類の変更を、今の道で読む
const pullLegacyChange = (
  store: SyncStore,
  {
    sequence,
    recordType,
    recordId,
  }: { sequence: number; recordType: RecordType; recordId: string },
): LegacySyncChange =>
  match(recordType)
    .with("weight_record", (): LegacySyncChange => {
      const weightRecord = store.findWeightRecord(recordId);
      if (weightRecord !== undefined) {
        return { sequence, type: "weight_record", weightRecord };
      }
      if (store.existsWeightRecordDeletion(recordId)) {
        return { sequence, type: "weight_record_deletion", recordId };
      }
      throw new Error(`変更の並びが指す体重記録も削除の印も無い: ${recordId}`);
    })
    .with("account_settings", (): LegacySyncChange => {
      const accountSettings = store.findAccountSettings();
      if (accountSettings === undefined) {
        throw new Error(`変更の並びが指すアカウントの設定が無い: ${recordId}`);
      }
      return { sequence, type: "account_settings", accountSettings };
    })
    .exhaustive();
