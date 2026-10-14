import type { DailyGuide } from "../../daily-guide/domain/daily-guide";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { ExpenditureEstimate } from "../../expenditure-estimate/domain/expenditure-estimate";
import type { Goal } from "./goal";

// 決めた目標から、応答に載せる記録を今の値で読む。決めたときも、同じ要求の ID の再送でも、同じ形になる。
// 同期の変更と同じ順に並べる: 立て直しなら閉じた前の目標を先に載せ、初めての目標なら推定消費カロリーの推定も載せる
export const readGoalDecisionRecords = (
  stores: Pick<RecordKindStores, "goal" | "dailyGuide" | "expenditureEstimate">,
  goal: Goal,
): GoalDecisionRecord[] => {
  const closedGoal = stores.goal.findClosedBy(goal.id);
  const dailyGuide = stores.dailyGuide.findByGoalAndEffectiveDay(goal.id, goal.startedOn);
  if (dailyGuide === undefined) {
    throw new Error("決めた目標に、開始の日から当てる1日の目安が無い");
  }
  if (closedGoal !== undefined) {
    return [
      { recordType: "goal", value: closedGoal },
      { recordType: "goal", value: goal },
      { recordType: "daily_guide", value: dailyGuide },
    ];
  }
  const estimate = stores.expenditureEstimate.find(dailyGuide.expenditureEstimateId);
  if (estimate === undefined) {
    throw new Error("1日の目安が指す推定消費カロリーの推定が無い");
  }
  return [
    { recordType: "goal", value: goal },
    { recordType: "daily_guide", value: dailyGuide },
    { recordType: "expenditure_estimate", value: estimate },
  ];
};

export type GoalDecisionRecord =
  | { recordType: "goal"; value: Goal }
  | { recordType: "daily_guide"; value: DailyGuide }
  | { recordType: "expenditure_estimate"; value: ExpenditureEstimate };
