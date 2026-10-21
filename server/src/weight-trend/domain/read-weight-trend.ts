import type { WeightRecordStore } from "../../weight-record/domain/weight-record-store";
import { computeWeightTrend } from "./compute-weight-trend";
import { readDailyWeights } from "./read-daily-weights";
import type { WeightTrend } from "./weight-trend";

// 体重記録（取り込んだもの、使い始める前のものを含む）から、今の体重の傾向を計算する。体重記録が無ければ空
export const readWeightTrend = (
  weightRecordStore: Pick<WeightRecordStore, "findAllInMeasuredOrder">,
): WeightTrend => computeWeightTrend(readDailyWeights(weightRecordStore));
