import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { Meal } from "./meal";

export type MealStore = {
  // 時刻は今の時刻（受け取った順でいちばんあとの修正。無ければ推定した時刻、それも無ければ作ったときの時刻）
  find: (id: RecordId) => Meal | undefined;
  hasDeletion: (id: RecordId) => boolean;
  // 渡した写真の ID のうち、どれかの食事の写真の宣言か、写真の削除の印にあるもの
  findUsedPhotoIds: (photoIds: readonly RecordId[]) => RecordId[];
  // 今の時刻が範囲（両端を含む）にある食事の、今の時刻と時差
  findEatenTimesBetween: (
    from: Date,
    to: Date,
  ) => Pick<Meal, "eatenAt" | "eatenAtUtcOffsetSeconds">[];
  // 送った時刻か今の時刻が from 以降の食事（多めに返す。返事の文脈を読むのに使う）
  findIdsSentOrEatenSince: (from: Date) => RecordId[];
  insert: (meal: Meal) => void;
  // 時刻の修正は書き込みの控えごとに足し、meals の時刻は書き換えない
  insertEatenAtCorrection: (receiptId: WriteReceiptId, eatenAt: Date) => void;
  // 食事を書き換えた控えから、時刻の修正の行を探して消す
  removeCorrections: (id: RecordId) => void;
  // 写真の宣言ごと消す
  remove: (id: RecordId) => void;
  // 削除の印は書き込みの控えを指すので、控えの ID を受け取る
  insertDeletion: (receiptId: WriteReceiptId) => void;
  insertPhotoDeletions: (photoIds: readonly RecordId[], receiptId: WriteReceiptId) => void;
};
