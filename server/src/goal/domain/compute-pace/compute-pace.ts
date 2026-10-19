import { addDays } from "../../../domain/add-days";
import { countDaysBetween } from "../../../domain/count-days-between";
import type { WeightTrend } from "../../../weight-trend/domain/weight-trend";
import { roundToTenthKg } from "../round-to-tenth-kg";
import type { WeightChangeDirection } from "../weight-change-direction";
import { floatingPointTolerance } from "../../../domain/floating-point-tolerance";
import { maintenanceBandKg } from "../maintenance-band-kg";

export type PaceGoal =
  | {
      direction: WeightChangeDirection;
      startedOn: string;
      deadlineOn: string;
      targetWeightKg: number;
    }
  | { direction: "maintain"; targetWeightKg: number };

// 速さと届かない kg は 0.1 kg に丸める。要るペースは週の振り返りの文だけが使う
export type Pace =
  // 間に合う
  | { status: "onTrack"; actualKgPerWeek: number; requiredKgPerWeek: number }
  // 届かない
  | { status: "behind"; shortfallKg: number; actualKgPerWeek: number; requiredKgPerWeek: number }
  // 言い切らない。直近 14 日に体重記録のある日が少ない
  | { status: "inconclusive"; weightRecordDayCount: number }
  // まだ出ない。目標を立てて 14 日たっていない
  | { status: "pending" }
  // 返さない。期限の日か達成した日を迎えた
  | { status: "unavailable" }
  // 維持（期限後の維持を含む）。体重の傾向が維持の幅に収まっているか
  | { status: "maintenance"; isWithinBand: boolean };

// ペース。端末にも同じ手順を置く（docs/agents/shared-rules.md の「ペース」）
export const computePace = ({
  judgedOn,
  weightTrend,
  weightRecordDays,
  goal,
  achievedOn,
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
    const trendKg = findTrendKgOnOrBefore(weightTrend, judgedOn);
    if (trendKg === undefined) {
      throw new Error("目標の開始の日より前に体重の傾向が無い");
    }
    // ちょうど幅の端にある傾向は、浮動小数の誤差で幅の外にしない
    const isWithinBand =
      Math.abs(trendKg - goal.targetWeightKg) <= maintenanceBandKg + floatingPointTolerance;
    return { status: "maintenance", isWithinBand };
  }
  if (judgedOn >= goal.deadlineOn || (achievedOn !== undefined && judgedOn >= achievedOn)) {
    return { status: "unavailable" };
  }
  // 14 日前の体重の傾向が目標の中にあるよう、開始の日から 14 日たつまでは出さない
  if (countDaysBetween(goal.startedOn, judgedOn) < 14) {
    return { status: "pending" };
  }
  // 判定する日とその前の 13 日
  const windowStartOn = addDays(judgedOn, -(windowDays - 1));
  const weightRecordDayCount = new Set(
    weightRecordDays.filter((day) => windowStartOn <= day && day <= judgedOn),
  ).size;
  if (weightRecordDayCount < minimumWeightRecordDayCount) {
    return { status: "inconclusive", weightRecordDayCount };
  }
  const judgedTrendKg = findTrendKgOnOrBefore(weightTrend, judgedOn);
  const earlierTrendKg = findTrendKgOnOrBefore(weightTrend, addDays(judgedOn, -windowDays));
  // 開始の日以前に体重の傾向がある目標だけが立つので、開始の日から 14 日たてば両方ある
  if (judgedTrendKg === undefined || earlierTrendKg === undefined) {
    throw new Error("目標の開始の日より前に体重の傾向が無い");
  }
  const actualKgPerWeek = (judgedTrendKg - earlierTrendKg) / 2;
  // 判定する日の翌日から期限の日までの週数
  const weeksToDeadline = countDaysBetween(judgedOn, goal.deadlineOn) / 7;
  const projectedKg = judgedTrendKg + actualKgPerWeek * weeksToDeadline;
  const rounded = {
    actualKgPerWeek: roundRateKg(actualKgPerWeek),
    requiredKgPerWeek: roundRateKg((goal.targetWeightKg - judgedTrendKg) / weeksToDeadline),
  };
  const sign = goal.direction === "lose" ? -1 : 1;
  // 目標体重へ向かう側に、あとどれだけ足りないか。ちょうど目標体重に届く見込みは、浮動小数の誤差で届かないことにしない
  const shortfallKg = sign * (goal.targetWeightKg - projectedKg);
  if (shortfallKg <= floatingPointTolerance) {
    return { status: "onTrack", ...rounded };
  }
  // 0.1 kg に満たない不足を「0.0 kg 届かない」と言わないよう、切り上げる
  return { status: "behind", shortfallKg: roundToTenthKg(shortfallKg, "ceil"), ...rounded };
};

// 体重の傾向は最後の体重記録の日で終わるので、その日以前で最も新しい日の値を使う
const findTrendKgOnOrBefore = (trend: WeightTrend, calendarDay: string): number | undefined =>
  trend.findLast((entry) => entry.calendarDay <= calendarDay)?.trendKg;

// -0.04 kg/週のような値が -0 にならないよう、0 を足して -0 を 0 にする（端末の JSON では 0 と -0 を分けない）
const roundRateKg = (kgPerWeek: number): number => roundToTenthKg(kgPerWeek, "round") + 0;

const windowDays = 14;

const minimumWeightRecordDayCount = 4;
