import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { Meal } from "./meal";

export type MealStore = {
  find: (id: string) => Meal | undefined;
  hasDeletion: (id: string) => boolean;
  // 渡した写真の ID のうち、どれかの食事の写真の宣言か、写真の削除の印にあるもの
  findUsedPhotoIds: (photoIds: readonly string[]) => string[];
  // 撮った時刻が範囲（両端を含む）にある食事の、撮った時刻と時差
  findEatenTimesBetween: (
    from: Date,
    to: Date,
  ) => Pick<Meal, "eatenAt" | "eatenAtUtcOffsetSeconds">[];
  insert: (meal: Meal) => void;
  // 食事を書き換えた控えから、時刻の修正の行を探して消す
  removeCorrections: (id: string) => void;
  // 写真の宣言ごと消す
  remove: (id: string) => void;
  // 削除の印は書き込みの控えを指すので、控えの ID を受け取る
  insertDeletion: (receiptId: WriteReceiptId) => void;
  insertPhotoDeletions: (photoIds: readonly string[], receiptId: WriteReceiptId) => void;
};
