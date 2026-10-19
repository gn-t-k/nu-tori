import { addDays } from "../../../domain/add-days";
import { findWeightTrendOnOrBefore } from "../../../weight-trend/domain/find-weight-trend-on-or-before";
import type { WeightTrend } from "../../../weight-trend/domain/weight-trend";
import type { Goal } from "../goal";
import { roundToTenthKg } from "../round-to-tenth-kg";

export type PostDeadlineMaintenanceGoal = Pick<
  Goal,
  "startingWeightTrendKg" | "targetWeightKg" | "weightChange"
>;

// 見直す月曜 M に、今の減量・増量の目標から期限後の維持へ移るか。M が期限の日より後なら移る（次の目標が選ばれていれば、今の目標は維持か期限の前）。
// 維持の目標の開始の日の体重の傾向は M の前の日曜の体重の傾向で、体重の傾向は最後の体重記録の日で終わるので、その週に体重が無ければ持ち越した傾向を使う。
// 目標体重は、目標を立てるときの維持と同じく、それを 0.1 kg 単位に丸めた値。移らないときは undefined
export const planPostDeadlineMaintenance = ({
  goal,
  reviewedMonday,
  weightTrend,
}: {
  goal: PostDeadlineMaintenanceGoal;
  // 見直す月曜 M（YYYY-MM-DD）
  reviewedMonday: string;
  weightTrend: WeightTrend;
}): { targetWeightKg: number; startingWeightTrendKg: number } | undefined => {
  if (goal.weightChange === undefined || reviewedMonday <= goal.weightChange.deadlineOn) {
    return undefined;
  }
  const sundayTrend = findWeightTrendOnOrBefore(weightTrend, addDays(reviewedMonday, -1));
  // 減量・増量の目標は開始の日以前の体重の傾向から立てるので、期限のあとの日曜の傾向はある
  if (sundayTrend === undefined) {
    throw new Error("期限後の維持に移る月曜の前の日曜に、体重の傾向が無い");
  }
  return {
    targetWeightKg: roundToTenthKg(sundayTrend.trendKg, "round"),
    startingWeightTrendKg: sundayTrend.trendKg,
  };
};
