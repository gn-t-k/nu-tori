import { computeDailyRepresentativeWeights } from "../../weight-record/domain/compute-daily-representative-weights";
import type { WeightRecordStore } from "../../weight-record/domain/weight-record-store";

// 体重の傾向の元になる、日の代表値の並び（日の順）。体重記録（取り込んだもの、使い始める前のものを含む）から選ぶ
export const readDailyWeights = (
  weightRecordStore: Pick<WeightRecordStore, "findAllInMeasuredOrder">,
): { calendarDay: string; weightKg: number }[] =>
  computeDailyRepresentativeWeights(weightRecordStore.findAllInMeasuredOrder()).map(
    ({ calendarDay, weightRecord }) => ({ calendarDay, weightKg: weightRecord.weightKg }),
  );
