import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { WeightRecord } from "./weight-record";

// 体重記録の置き場。削除の印は体重記録の削除の印の表のまま持つ
export type WeightRecordStore = {
  findStartedOn: () => string | undefined;
  find: (id: string) => WeightRecord | undefined;
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
