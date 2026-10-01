import type { createRecordKinds } from "./create-record-kinds";
import type { KindWrites } from "./sync-ledger/record-kind";
import type { WriteBase } from "./sync-ledger/write-base";

// 書き込みは、登録簿の種類が宣言する書き込みの union
export type SyncWrite = WriteOfKind<ReturnType<typeof createRecordKinds>[number]>;

type WriteOfKind<TKind> = TKind extends {
  writes: KindWrites<infer TWrite extends WriteBase, string> | undefined;
}
  ? TWrite
  : never;
