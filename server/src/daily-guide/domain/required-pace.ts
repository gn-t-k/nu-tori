import { weeklyPaceRates } from "../../goal/domain/weekly-pace-rates";
import type { WeightChangeDirection } from "../../goal/domain/weight-change-direction";

// 必要な速さを出すのに使う、目標と体重の傾向の値。
// 目標を立てた・立て直したときは開始の日の値、見直しでは見直す月曜 M の前の日曜の体重の傾向と M から期限の日までの日数
export type RequiredPaceGoal =
  | { direction: "maintain"; targetWeightKg: number; weightTrendKg: number }
  | {
      direction: WeightChangeDirection;
      // 目標の開始の日の体重の傾向。ハード案の速さの上限を出す元で、目標のあいだは変わらない
      goalStartingWeightTrendKg: number;
      targetWeightKg: number;
      weightTrendKg: number;
      // 新しい1日の目安を当てる最初の日から期限の日までの日数（両端を含む）
      daysToDeadline: number;
    };

// 必要な速さ（kg/日。減量は負）。減量・増量は目標の向きと逆にせず、ハード案の速さまでに抑える。
// 維持は、体重の傾向が目標体重の ±0.7 kg の中なら 0、外れたら体重の傾向の 0.15%/週の速さで目標体重へ戻す
export const computeRequiredPace = (
  goal: RequiredPaceGoal,
): { kgPerDay: number; isLimited: boolean } => {
  if (goal.direction === "maintain") {
    const differenceKg = goal.targetWeightKg - goal.weightTrendKg;
    if (Math.abs(differenceKg) <= maintenanceToleranceKg + tolerance) {
      return { kgPerDay: 0, isLimited: false };
    }
    return {
      kgPerDay: (Math.sign(differenceKg) * maintenanceWeeklyRate * goal.weightTrendKg) / 7,
      isLimited: false,
    };
  }
  // 期限まで7日に満たないときは7日で割り、残りの日数で速さが跳ね上がらないようにする
  const days = Math.max(goal.daysToDeadline, 7);
  const sign = goal.direction === "lose" ? -1 : 1;
  // 達成したあとに目標体重を越えても、目標体重へ戻さない
  const towardGoalKgPerDay = Math.max(
    (sign * (goal.targetWeightKg - goal.weightTrendKg)) / days,
    0,
  );
  const maximumKgPerDay =
    (weeklyPaceRates[goal.direction].hard * goal.goalStartingWeightTrendKg) / 7;
  // ハード案の目標体重は上限ちょうどの速さになるので、浮動小数の誤差で上限に当たったことにしない
  const isLimited = towardGoalKgPerDay > maximumKgPerDay * (1 + tolerance);
  return { kgPerDay: sign * Math.min(towardGoalKgPerDay, maximumKgPerDay), isLimited };
};

// 維持で保つ幅と、外れたときに戻す速さ（体重の傾向に対する、1週間に変わる割合）。出荷後に調整する初期値
const maintenanceToleranceKg = 0.7;
const maintenanceWeeklyRate = 0.0015;

const tolerance = 1e-9;
