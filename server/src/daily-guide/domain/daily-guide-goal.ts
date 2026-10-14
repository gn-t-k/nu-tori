import type { WeightChangeDirection } from "../../goal/domain/weight-change-direction";

// 1日の目安の計算に使う、目標の値。維持は目標体重へ向かう速さが無いので、開始の日の体重の傾向と期限を持たない
export type DailyGuideGoal =
  | { direction: "maintenance"; targetWeightKg: number }
  | {
      direction: WeightChangeDirection;
      startingWeightTrendKg: number;
      targetWeightKg: number;
      // 開始の日から期限の日までの日数（両端を含む）
      daysFromStartToDeadline: number;
    };
