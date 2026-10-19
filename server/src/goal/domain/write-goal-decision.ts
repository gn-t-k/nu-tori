import { type DailyGuide, dailyGuideLimitTypes } from "../../daily-guide/domain/daily-guide";
import type { RecordChangeWrites } from "../../domain/record-change-writes";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import {
  type InitialExpenditureSource,
  initialExpenditureSources,
} from "../../expenditure-estimate/domain/expenditure-estimate";
import { type DecidedGoal, type Goal, pacePlans } from "./goal";
import { isListed } from "../../domain/is-listed";

// 目標を決めたことを書く口。初めての目標と立て直しの行の組を、外部キーが指す行を先にして書き、変えた記録を足す。
// 記録の変化を書く入口（RecordChangeWriter）の run の中で呼ぶ。
// 表で守らない決まり（今の目標は 0..1、開始の日を戻さない、推定の始まりは1つ、区分の値）は、書く前にここで確かめて投げる
export const writeGoalDecision = (
  stores: Pick<RecordKindStores, "goal" | "dailyGuide" | "expenditureEstimate">,
  addChange: RecordChangeWrites["addChange"],
  decision: {
    // 端末が振った要求の ID。受け取りの行の ID になる
    requestId: string;
    goal: Omit<DecidedGoal, "id">;
    // 目標の開始の日から当てる
    dailyGuide: Pick<
      DailyGuide,
      "energyKcal" | "proteinG" | "fatG" | "carbohydrateG" | "limitHits"
    >;
    // 初めての目標のときだけ渡す。立て直しは推定を作らず、今の推定を指す
    initialExpenditure: InitialExpenditure | undefined;
  },
): RecordId => {
  const { requestId, goal, dailyGuide, initialExpenditure } = decision;
  const currentGoal = stores.goal.findCurrent();
  const currentEstimateId = stores.expenditureEstimate.findCurrent()?.id;
  requireWritable({ goal, dailyGuide, initialExpenditure, currentGoal, currentEstimateId });

  const goalId = generateRecordId();
  const dailyGuideId = generateRecordId();
  const expenditureEstimateId = currentEstimateId ?? generateRecordId();
  if (initialExpenditure !== undefined) {
    stores.expenditureEstimate.insert({
      id: expenditureEstimateId,
      effectiveOn: goal.startedOn,
      expenditureKcal: initialExpenditure.expenditureKcal,
      estimatedAt: goal.decidedAt,
      initialSource: initialExpenditure.source,
    });
  }
  stores.goal.insert({ ...goal, id: goalId });
  // 今の目標をいつも閉じるので、閉じていない目標は新しい目標の1つになる
  if (currentGoal !== undefined) {
    stores.goal.insertClosure({ goalId: currentGoal.id, nextGoalId: goalId });
  }
  stores.dailyGuide.insert({
    ...dailyGuide,
    id: dailyGuideId,
    goalId,
    expenditureEstimateId,
    effectiveOn: goal.startedOn,
  });
  stores.goal.insertDecisionReceipt({ requestId, goalId });

  // 閉じた事実を目標の記録に載せ直す。新しい目標より先に届ける
  if (currentGoal !== undefined) {
    addChange({ recordType: "goal", recordId: currentGoal.id });
  }
  addChange({ recordType: "goal", recordId: goalId });
  addChange({ recordType: "daily_guide", recordId: dailyGuideId });
  if (initialExpenditure !== undefined) {
    addChange({ recordType: "expenditure_estimate", recordId: expenditureEstimateId });
  }
  return goalId;
};

type InitialExpenditure = { expenditureKcal: number; source: InitialExpenditureSource };

const requireWritable = ({
  goal,
  dailyGuide,
  initialExpenditure,
  currentGoal,
  currentEstimateId,
}: {
  goal: Omit<DecidedGoal, "id">;
  dailyGuide: Pick<DailyGuide, "limitHits">;
  initialExpenditure: InitialExpenditure | undefined;
  currentGoal: Goal | undefined;
  currentEstimateId: RecordId | undefined;
}): void => {
  if (initialExpenditure !== undefined && currentEstimateId !== undefined) {
    throw new Error("推定消費カロリーの推定がもうあるのに、推定の始まりを書こうとした");
  }
  if (initialExpenditure === undefined && currentEstimateId === undefined) {
    throw new Error("推定消費カロリーの推定が無いのに、推定の始まりを渡していない");
  }
  if (currentGoal !== undefined && goal.startedOn < currentGoal.startedOn) {
    throw new Error("新しい目標の開始の日が、今の目標の開始の日より前");
  }
  if (goal.weightChange !== undefined && goal.targetWeightKg === goal.startingWeightTrendKg) {
    throw new Error("減量・増量の目標の目標体重が、開始の日の体重の傾向と等しい");
  }
  // 区分の列に CHECK は無いので、型をすり抜けた値をここで止める
  if (goal.weightChange !== undefined && !isListed(pacePlans, goal.weightChange.pacePlan)) {
    throw new Error("速さの案の値が一覧に無い");
  }
  if (
    initialExpenditure !== undefined &&
    !isListed(initialExpenditureSources, initialExpenditure.source)
  ) {
    throw new Error("推定の始まりの出どころの値が一覧に無い");
  }
  if (!dailyGuide.limitHits.every((limitType) => isListed(dailyGuideLimitTypes, limitType))) {
    throw new Error("当たった上限と下限の値が一覧に無い");
  }
};
