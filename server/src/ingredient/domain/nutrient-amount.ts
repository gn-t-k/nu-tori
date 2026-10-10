// 料理・食事・日の栄養の合計の1項目。値の分かる材料の分だけを足し、「不明」の材料が混じれば以上、すべて「不明」なら不明
export type NutrientAmount =
  | { type: "exactly"; value: number }
  | { type: "at_least"; value: number }
  | { type: "unknown" };
