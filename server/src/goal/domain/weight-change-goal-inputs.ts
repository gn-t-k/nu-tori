import type { WeightChangeDirection } from "./weight-change-direction";

// 減量・増量の目標案・受け付ける目標体重・自分で決めた目標体重を計算する元
export type WeightChangeGoalInputs = {
  direction: WeightChangeDirection;
  expenditureKcal: number;
  startingWeightTrendKg: number;
  // 開始の日から期限の日までの日数（両端を含む）
  daysFromStartToDeadline: number;
};
