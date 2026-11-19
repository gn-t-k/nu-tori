import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/create-sync-ledger";
import type { WeightRecord } from "./weight-record";

// 体重・測った時刻・タイムゾーンは、どの読む口も今の値（受け取った順でいちばんあとの修正、無ければ作ったときの値）を返す。
// 版は、1 ＋ その記録の当てた直す書き込みの控えの数
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
  // 体重の修正か時刻の修正が1行でもあるか。同じ値で保存しただけの記録は、直したことにならない
  hasCorrection: (id: RecordId) => boolean;
  insert: (record: Omit<WeightRecord, "version">) => void;
  // 修正は書き込みの控えを指すので、控えの ID を受け取る。記録の ID は控えにある
  insertWeightCorrection: (receiptId: WriteReceiptId, weightKg: number) => void;
  insertMeasuredAtCorrection: (
    receiptId: WriteReceiptId,
    measuredAt: Pick<WeightRecord, "measuredAt" | "timeZone">,
  ) => void;
  remove: (id: RecordId) => void;
  // 削除の印は書き込みの控えを指すので、控えの ID を受け取る
  insertDeletion: (receiptId: WriteReceiptId) => void;
};
