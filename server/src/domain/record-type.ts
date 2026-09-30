import type { createRecordKinds } from "./create-record-kinds";
import type { NameOfKind } from "./sync-ledger/name-of-kind";

// 種類の名前は登録簿から導く。表の宣言の列挙（sync-ledger-tables.ts）は、ここに代入できる形で手で書く
export type RecordType = NameOfKind<ReturnType<typeof createRecordKinds>[number]>;
