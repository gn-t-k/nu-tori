import { generateRecordId, type RecordId } from "../../domain/record-id";
import { millisecondsPerDay } from "../../domain/milliseconds-per-day";
import type { WriteReceiptId } from "../../domain/sync-ledger/sync-ledger";
import { learnUsualWeighingTime, usualWeighingTimeRangeDays } from "./learn-usual-weighing-time";
import type { UsualWeighingTimeStore } from "./usual-weighing-time-store";

// 体重記録の書き込みを当てたあとの体重記録で、いつもの時刻を学び直す。
// 値が今と変わるときだけ、学び直しを書き、変えた記録の ID を返す。
// 3日そろわないときは、今の値を残す（一度学んだら、体重記録をすべて消しても消さない）
export const relearnUsualWeighingTime = (
  store: UsualWeighingTimeStore,
  input: {
    // 時刻が from 以上 to 未満の体重記録を読む
    findWeightRecordsMeasuredBetween: (from: Date, to: Date) => readonly WeightRecordTime[];
    now: Date;
    // ユーザーの最新のタイムゾーン。読めなければ undefined
    latestTimeZone: string | undefined;
  },
  // きっかけの体重の書き込みの控え
  receiptId: WriteReceiptId,
): RecordId | undefined => {
  // 学ぶ範囲（基準の今日と、その前の usualWeighingTimeRangeDays - 1 日）に入りうる記録だけを読む。日付は記録ごとのタイムゾーンで決まるので、時差の分だけ広く読む
  const timeZoneMarginDays = 2;
  const weightRecords = input
    .findWeightRecordsMeasuredBetween(
      new Date(
        input.now.getTime() -
          (usualWeighingTimeRangeDays + timeZoneMarginDays) * millisecondsPerDay,
      ),
      // 基準の今日の終わりまでの1日と、時差の分
      new Date(input.now.getTime() + (1 + timeZoneMarginDays) * millisecondsPerDay),
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
  // 行は1つだけ。初めて学ぶときだけ ID を振る
  const id = current?.id ?? generateRecordId();
  if (current === undefined) {
    store.insert(id);
  }
  store.insertChange(receiptId, learned);
  return id;
};

type WeightRecordTime = { id: RecordId; measuredAt: Date; timeZone: string };
