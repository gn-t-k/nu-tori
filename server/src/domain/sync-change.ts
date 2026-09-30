import type { RecordType } from "./record-type";
import type { LedgerChange } from "./sync-ledger/sync-ledger";

// 変更は、登録簿の種類の分だけ。値の型は種類ごとに違い、受け口が種類の名前で引いて変換する
export type SyncChange = LedgerChange<RecordType, unknown>;
