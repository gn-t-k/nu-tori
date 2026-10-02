import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import type { RecordChangeTarget } from "../../domain/sync-ledger/record-change-target";
import { learnUsualWeighingTime } from "./learn-usual-weighing-time";
import type { UsualWeighingTimeStore } from "./usual-weighing-time-store";

// 体重記録の書き込みを当てたあとの体重記録で、いつもの時刻を学び直す。読むだけで、書かない。
// 値が今と変わるときだけ、載せる変更と、控えを書いたあとに学び直しを書く処理を返す。
// 3日そろわないときは、今の値を残す（一度学んだら、体重記録をすべて消しても消さない）
export const relearnUsualWeighingTime = (
  store: UsualWeighingTimeStore,
  input: {
    // 時刻が from 以上 to 未満の体重記録を読む
    findWeightRecordsMeasuredBetween: (from: Date, to: Date) => readonly WeightRecordTime[];
    // 読んだ体重記録に、書き込みを当てたあとの体重記録をメモリの上で出す
    applyWrite: (weightRecords: readonly WeightRecordTime[]) => readonly WeightRecordTime[];
    now: Date;
    // ユーザーの最新のタイムゾーン。読めなければ undefined
    latestTimeZone: string | undefined;
  },
):
  | {
      change: RecordChangeTarget<"usual_weighing_time">;
      commit: (receiptId: WriteReceiptId) => void;
    }
  | undefined => {
  // 範囲（基準の今日とその前の 27 日）に入りうる記録だけを読む。日付は記録ごとのタイムゾーンで決まるので、時差の分だけ広く読む
  const weightRecords = input
    .applyWrite(
      input.findWeightRecordsMeasuredBetween(
        new Date(input.now.getTime() - 30 * dayMilliseconds),
        new Date(input.now.getTime() + 3 * dayMilliseconds),
      ),
    )
    .toSorted((a, b) => a.measuredAt.getTime() - b.measuredAt.getTime());
  // 最新のタイムゾーンが読めないときは、最後の体重記録のタイムゾーン（受け付けるときに確かめてある）で今日を決める
  const timeZone = input.latestTimeZone ?? weightRecords.at(-1)?.timeZone;
  if (timeZone === undefined) {
    return undefined;
  }
  const learned = learnUsualWeighingTime({
    weightRecords,
    now: input.now,
    timeZone,
  });
  const current = store.find();
  if (learned === undefined || learned === current?.minuteOfDay) {
    return undefined;
  }
  // 行は1つだけ。今の行を読んでから、初めて学ぶときだけ ID を振る
  const id = current?.id ?? crypto.randomUUID();
  return {
    change: { recordType: "usual_weighing_time", recordId: id },
    commit: (receiptId) => {
      if (current === undefined) {
        store.insert(id);
      }
      store.insertChange(receiptId, learned);
    },
  };
};

type WeightRecordTime = { id: string; measuredAt: Date; timeZone: string };

const dayMilliseconds = 24 * 60 * 60 * 1000;
