import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { UsualWeighingTime } from "./usual-weighing-time";

export type UsualWeighingTimeStore = {
  // 学び直しで値が変わった事実のうち、最後のもの。まだ学んでいなければ undefined
  find: () => UsualWeighingTime | undefined;
  // 初めて学んだときだけ、記録の行を書く
  insert: (id: string) => void;
  // 学び直しは、きっかけの体重の書き込みの控えを指すので、控えの ID を受け取る
  insertChange: (receiptId: WriteReceiptId, minuteOfDay: number) => void;
};
