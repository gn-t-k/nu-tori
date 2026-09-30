import type { RecordType } from "../../domain/record-type";
import type { PresentRecord } from "../../domain/sync-ledger/present-record";
import type { WriteBase } from "../../domain/sync-ledger/write-base";
import type { SyncWrite } from "../../domain/sync-write";

// 記録の種類が受け口に見せる入口。ドメインの登録簿の種類と、名前を揃えて1行ずつ並べる
// メソッドの書き方は、登録簿の配列に型の違う種類を並べるため（引数を双変にする）
export type HttpRecordKind<TValue = unknown, TWriteInput extends WriteBase = WriteBase> = {
  name: RecordType;
  // 端末からの書き込みの type。宣言しない種類（サーバーだけが書く種類）は空。スキーマは registered-write-schemas.ts に並べる
  writeTypes: readonly string[];
  toWrite(write: TWriteInput): SyncWrite;
  toChangeResponse(
    sequence: number,
    current: PresentRecord<TValue>,
    recordId: string,
  ): { sequence: number; kind: string; recordId: string; record: Record<string, unknown> };
};
