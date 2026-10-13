import { createRecordKinds } from "./create-record-kinds";
import type { RecordKindStores } from "./record-kind-stores";
import type { RecordType } from "./record-type";
import type { LedgerStore } from "./sync-ledger/ledger-store";
import { createSyncLedger } from "./sync-ledger/sync-ledger";
import type { SyncWrite } from "./sync-write";

// 登録簿の種類で組んだ帳簿。書き込みの型は登録簿から導いた SyncWrite、種類の名前の型は名前の一覧から導いた RecordType
export const createRecordLedger = (
  ledgerStore: LedgerStore<RecordType>,
  stores: RecordKindStores,
  receivedAt: Date,
) =>
  createSyncLedger<RecordType, RecordType, SyncWrite, unknown>(
    ledgerStore,
    createRecordKinds(stores, receivedAt),
  );
