import { kilocaloriesPerKilogram } from "../../domain/kilocalories-per-kilogram";

// 見直す週の記録が意味する消費（kcal/日）。食事を記録した日の平均から、体重の傾向の変化を1日あたりの kcal にした分を引く。
// 推定の更新では観測として使い、見直しの判定では記録の抜けを見つけるのに使う
export const computeObservedExpenditure = ({
  averageEnergyIntakeKcal,
  actualWeightChangeKg,
  weightChangeDayCount,
}: {
  averageEnergyIntakeKcal: number;
  actualWeightChangeKg: number;
  weightChangeDayCount: number;
}): number =>
  averageEnergyIntakeKcal - (kilocaloriesPerKilogram * actualWeightChangeKg) / weightChangeDayCount;
