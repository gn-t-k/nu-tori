import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { UsualWeighingTime } from "./usual-weighing-time";
import type { UsualWeighingTimeStore } from "./usual-weighing-time-store";

// いつもの時刻の種類。サーバーだけが書く（体重記録の種類が、書き込みを当てるたびに学び直す）。
// 学ぶまでは変更の並びに出ず、一度学んだら消えないので、無くなったことは届けない
export const createUsualWeighingTimeKind = (
  store: UsualWeighingTimeStore,
): RecordKind<"usual_weighing_time", never, UsualWeighingTime> => ({
  name: "usual_weighing_time",
  writes: undefined,
  deliversAbsence: false,
  readCurrent: (recordId): CurrentRecord<UsualWeighingTime> => {
    const usualWeighingTime = store.find();
    return usualWeighingTime?.id === recordId
      ? { status: "value", value: usualWeighingTime }
      : { status: "absent" };
  },
});
