import type { CurrentRecord } from "../../domain/sync-ledger/current-record";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import { computeDailyRepresentativeWeights } from "../../weight-record/domain/compute-daily-representative-weights";
import type { WeightRecordStore } from "../../weight-record/domain/weight-record-store";
import { computeWeightTrend } from "./compute-weight-trend";
import type { WeightTrend } from "./weight-trend";
import { weightTrendRecordId } from "./weight-trend-record-id";

// 体重の傾向の種類。サーバーだけが書く。行を持たず、取りに行くたびに体重記録（取り込んだもの、使い始める前のものを含む）から計算する。
// 記録はアカウントに1つで、体重記録が1つも無ければ無いことを届ける
export const createWeightTrendKind = (
  weightRecordStore: WeightRecordStore,
): RecordKind<"weight_trend", never, WeightTrend, never, "weight_record"> => ({
  name: "weight_trend",
  writes: undefined,
  // 行を持たないので書かず、変わったことだけを並びに載せる
  follows: { source: "weight_record", afterSourceApplied: () => [weightTrendRecordId] },
  deliversAbsence: true,
  readCurrent: (): CurrentRecord<WeightTrend> => {
    const representatives = computeDailyRepresentativeWeights(
      weightRecordStore.findAllInMeasuredOrder(),
    );
    if (representatives.length === 0) {
      return { status: "absent" };
    }
    return {
      status: "value",
      value: computeWeightTrend(
        representatives.map(({ calendarDay, weightRecord }) => ({
          calendarDay,
          weightKg: weightRecord.weightKg,
        })),
      ),
    };
  },
});
