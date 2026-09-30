import type { createRecordKinds } from "./create-record-kinds";
import type { WriteOfKind } from "./sync-ledger/write-of-kind";

// 書き込みは、登録簿の種類が宣言する書き込みの union
export type SyncWrite = WriteOfKind<ReturnType<typeof createRecordKinds>[number]>;
