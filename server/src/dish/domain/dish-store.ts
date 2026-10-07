import type { RecordId } from "../../domain/record-id";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { Dish, DishEstimationApplication, NewDish } from "./dish";
import type { DishQuantityCorrection } from "./dish-write";

export type DishStore = {
  // 今の値（量と単位と版は出来事から出す）
  find: (id: RecordId) => Dish | undefined;
  exists: (id: RecordId) => boolean;
  hasDeletion: (id: RecordId) => boolean;
  // 使う人が足した料理か（料理を作る書き込みを当てた控えがある）。料理に作り手は持たない
  wasAddedByUser: (id: RecordId) => boolean;
  // 料理が対象の推定（推定し直し）を当てたうち、いちばん新しいものの終わり（完了か断念）の時刻。当てていなければ undefined
  findNewestReestimationEndedAt: (id: RecordId) => Date | undefined;
  findIdsOfMeal: (mealId: RecordId) => RecordId[];
  insert: (dish: NewDish) => void;
  // 当てた推定と推定の量（あれば）を書く。材料はこのあとに、同じ推定の ID を付けて書く
  insertEstimationApplication: (application: DishEstimationApplication) => void;
  // 料理を直した書き込みの控えに、直した名前を書く（料理は控えの record_id）
  insertNameCorrection: (receiptId: WriteReceiptId, name: string) => void;
  // 料理を直した書き込みの控えに、直した量と比例させた材料の量の明細を書く
  insertQuantityCorrection: (receiptId: WriteReceiptId, correction: DishQuantityCorrection) => void;
  // 材料を先に消してから呼ぶ（材料の親は外部キーで守っている）。当てた推定と推定の量は CASCADE で消える
  remove: (ids: readonly RecordId[]) => void;
  // 料理を書き換えた控えから、名前と量の修正の行を探して消す（比例の明細は CASCADE で消える）
  removeCorrections: (ids: readonly RecordId[]) => void;
  // 消した書き込みの控えつきで、削除の印を書く
  insertDeletions: (ids: readonly RecordId[], receiptId: WriteReceiptId) => void;
};
