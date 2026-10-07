import type { RecordId } from "../../domain/record-id";

// 推定の予定と推定が対象にする記録。写真の推定は食事を、名前を直した・料理を足したときの推定し直しは料理を対象にする。
// 料理の対象も食事を持つ（写真を読み、ユーザーのタイムゾーンが読めないときに食事を送ったときのものを使うため）
export type EstimationTarget =
  | { type: "meal"; mealId: RecordId }
  | { type: "dish"; dishId: RecordId; mealId: RecordId };
