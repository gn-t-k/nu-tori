import { createServerOnlyKind } from "../../domain/sync-ledger/create-server-only-kind";
import type { RecordKind } from "../../domain/sync-ledger/record-kind";
import type { WeightRecordStore } from "../../weight-record/domain/weight-record-store";
import { readWeightTrend } from "./read-weight-trend";
import type { WeightTrend } from "./weight-trend";
import { weightTrendRecordId } from "./weight-trend-record-id";

// 体重の傾向の種類。サーバーだけが書く。行を持たず、取りに行くたびに体重記録（取り込んだもの、使い始める前のものを含む）から計算する。
// 記録はアカウントに1つで、体重記録が1つも無ければ無いことを届ける
export const createWeightTrendKind = (
  weightRecordStore: WeightRecordStore,
): RecordKind<"weight_trend", never, WeightTrend, never, "weight_record"> =>
  createServerOnlyKind({
    name: "weight_trend",
    // 行を持たないので書かず、変わったことだけを並びに載せる
    follows: { source: "weight_record", afterSourceApplied: () => [weightTrendRecordId] },
    whenGone: "absence",
    find: () => {
      const weightTrend = readWeightTrend(weightRecordStore);
      return weightTrend.length === 0 ? undefined : weightTrend;
    },
  });
