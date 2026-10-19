import { addDays } from "../../../domain/add-days";
import { countDaysBetween } from "../../../domain/count-days-between";
import type { WeightTrend } from "../../../weight-trend/domain/weight-trend";
import { roundToTenthKg } from "../round-to-tenth-kg";
import type { WeightChangeDirection } from "../weight-change-direction";

export type PaceGoal =
  | {
      direction: WeightChangeDirection;
      startedOn: string;
      deadlineOn: string;
      targetWeightKg: number;
    }
  | { direction: "maintain"; targetWeightKg: number };

export type Pace =
  | { status: "onTrack"; actualKgPerWeek: number; requiredKgPerWeek: number }
  | { status: "behind"; shortfallKg: number; actualKgPerWeek: number; requiredKgPerWeek: number };

// ペース。端末にも同じ手順を置く（docs/agents/shared-rules.md の「ペース」）
export const computePace = ({
  judgedOn,
  weightTrend,
  goal,
}: {
  // 判定する日（YYYY-MM-DD）。週の振り返りではその週の日曜、ほかは今日
  judgedOn: string;
  weightTrend: WeightTrend;
  // 体重記録のある日（YYYY-MM-DD）
  weightRecordDays: readonly string[];
  goal: PaceGoal;
  achievedOn: string | undefined;
}): Pace => {
  if (goal.direction === "maintain") {
    throw new Error("まだ無い");
  }
  const judgedTrendKg = findTrendKgOnOrBefore(weightTrend, judgedOn);
  const earlierTrendKg = findTrendKgOnOrBefore(weightTrend, addDays(judgedOn, -14));
  if (judgedTrendKg === undefined || earlierTrendKg === undefined) {
    throw new Error("まだ無い");
  }
  const actualKgPerWeek = (judgedTrendKg - earlierTrendKg) / 2;
  // 判定する日の翌日から期限の日までの週数
  const weeksToDeadline = countDaysBetween(judgedOn, goal.deadlineOn) / 7;
  const projectedKg = judgedTrendKg + actualKgPerWeek * weeksToDeadline;
  const rounded = {
    actualKgPerWeek: roundToTenthKg(actualKgPerWeek, "round"),
    requiredKgPerWeek: roundToTenthKg(
      (goal.targetWeightKg - judgedTrendKg) / weeksToDeadline,
      "round",
    ),
  };
  const sign = goal.direction === "lose" ? -1 : 1;
  // 目標体重へ向かう側に、あとどれだけ足りないか。ちょうど目標体重に届く見込みは、浮動小数の誤差で届かないことにしない
  const shortfallKg = sign * (goal.targetWeightKg - projectedKg);
  if (shortfallKg <= tolerance) {
    return { status: "onTrack", ...rounded };
  }
  // 0.1 kg に満たない不足を「0.0 kg 届かない」と言わないよう、切り上げる
  return { status: "behind", shortfallKg: roundToTenthKg(shortfallKg, "ceil"), ...rounded };
};

// 体重の傾向は最後の体重記録の日で終わるので、その日以前で最も新しい日の値を使う
const findTrendKgOnOrBefore = (trend: WeightTrend, calendarDay: string): number | undefined =>
  trend.findLast((entry) => entry.calendarDay <= calendarDay)?.trendKg;

const tolerance = 1e-9;
