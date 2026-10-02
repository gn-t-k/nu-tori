import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { WeightRecord } from "./weight-record";

export type WeightRecordStore = {
  find: (id: string) => WeightRecord | undefined;
  // 体重の傾向の計算に使う。取り込みの情報は読まない
  findAllInMeasuredOrder: () => Pick<WeightRecord, "id" | "weightKg" | "measuredAt" | "timeZone">[];
  existsImportedSample: (healthkitSampleUuid: string) => boolean;
  hasDeletion: (recordId: string) => boolean;
  insert: (record: WeightRecord) => void;
  update: (
    id: string,
    correction: Pick<WeightRecord, "weightKg" | "measuredAt" | "timeZone" | "version">,
  ) => void;
  remove: (id: string) => void;
  // 削除の印は書き込みの控えを指すので、控えの ID を受け取る
  insertDeletion: (receiptId: WriteReceiptId) => void;
};
