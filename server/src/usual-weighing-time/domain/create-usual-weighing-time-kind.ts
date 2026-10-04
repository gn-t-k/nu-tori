import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { WeightRecordStore } from "../../weight-record/domain/weight-record-store";
import { relearnUsualWeighingTime } from "./relearn-usual-weighing-time";
import type { UsualWeighingTime } from "./usual-weighing-time";
import type { UsualWeighingTimeStore } from "./usual-weighing-time-store";

// いつもの時刻の種類。サーバーだけが書く（体重記録の書き込みを当てるたびに学び直す）。
// 学ぶまでは変更の並びに出ず、一度学んだら消えないので、無くなったことは届けない
export const createUsualWeighingTimeKind = (dependencies: {
  store: UsualWeighingTimeStore;
  weightRecordStore: Pick<WeightRecordStore, "findMeasuredBetween">;
  // ユーザーの最新のタイムゾーン。基準の今日を決める。読めなければ undefined
  findLatestTimeZone: () => string | undefined;
  // 要求を受け取った時刻
  receivedAt: Date;
}): RecordKind<"usual_weighing_time", never, UsualWeighingTime, never, "weight_record"> => ({
  name: "usual_weighing_time",
  writes: undefined,
  follows: {
    source: "weight_record",
    afterSourceApplied: (receiptId) => {
      const relearnedId = relearnUsualWeighingTime(
        dependencies.store,
        {
          findWeightRecordsMeasuredBetween: dependencies.weightRecordStore.findMeasuredBetween,
          now: dependencies.receivedAt,
          latestTimeZone: dependencies.findLatestTimeZone(),
        },
        receiptId,
      );
      return relearnedId === undefined ? [] : [relearnedId];
    },
  },
  whenGone: "never",
  readCurrent: (recordId): CurrentRecord<UsualWeighingTime> => {
    const usualWeighingTime = dependencies.store.find();
    return usualWeighingTime?.id === recordId
      ? { status: "value", value: usualWeighingTime }
      : { status: "absent" };
  },
});
