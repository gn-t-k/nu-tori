import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { WeightRecord } from "./weight-record";

export type WeightRecordStore = {
  find: (id: RecordId) => WeightRecord | undefined;
  // 体重の傾向の計算に使う。取り込みの情報は読まない
  findAllInMeasuredOrder: () => Pick<WeightRecord, "id" | "weightKg" | "measuredAt" | "timeZone">[];
  // いつもの時刻の学び直しに使う。from 以上 to 未満の時刻の記録を、時刻の順に読む
  findMeasuredBetween: (
    from: Date,
    to: Date,
  ) => Pick<WeightRecord, "id" | "measuredAt" | "timeZone">[];
  existsImportedSample: (healthkitSampleUuid: string) => boolean;
  hasDeletion: (recordId: RecordId) => boolean;
  insert: (record: WeightRecord) => void;
  update: (
    id: RecordId,
    correction: Pick<WeightRecord, "weightKg" | "measuredAt" | "timeZone" | "version">,
  ) => void;
  remove: (id: RecordId) => void;
  // 削除の印は書き込みの控えを指すので、控えの ID を受け取る
  insertDeletion: (receiptId: WriteReceiptId) => void;
};
