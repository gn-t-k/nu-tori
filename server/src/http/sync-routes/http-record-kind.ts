import type { PresentRecord, WriteBase } from "../../domain/sync-ledger/record-kind";
import type { SyncWrite } from "../../domain/sync-write";

// 記録の種類が受け口に見せる入口。ドメインの登録簿の種類と、名前を揃えて1行ずつ並べる
export type HttpRecordKind = {
  name: string;
  // 端末からの書き込みの type。宣言しない種類（サーバーだけが書く種類）は空。スキーマは registered-write-schemas.ts に並べる
  writeTypes: readonly string[];
  toWrite(write: WriteBase): SyncWrite;
  toChangeResponse(
    sequence: number,
    current: PresentRecord<unknown>,
  ): { sequence: number; kind: string; recordId: string; record: Record<string, unknown> };
};
