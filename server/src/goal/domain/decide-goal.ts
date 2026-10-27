import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordChangeWrites } from "../../domain/record-change-writes";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { UsageEvent } from "../../domain/usage-event";
import type { CustomTargetWeightRejectionReason } from "./custom-target-weight-rejection-reason";
import type { GoalDirection } from "./goal-direction";
import {
  assessGoalDecision,
  type GoalChoice,
  type GoalDecisionAssessment,
  type GoalProposals,
  type ShownGoal,
} from "./goal-offer";
import { type CompleteGoalSetupBasis, resolveCompleteGoalSetupBasis } from "./goal-setup-basis";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import { type GoalDecisionRecord, readGoalDecisionRecords } from "./read-goal-decision-records";
import type { GoalSetupStores } from "./goal-setup-stores";
import { writeGoalDecision } from "./write-goal-decision";

export type GoalDecisionRequest = GoalSetupSituation & {
  // 端末が振った要求の ID。同じ ID の再送は、書かずに初めてと同じ形で答える
  requestId: string;
  // 目標案の応答で受け取った開始の日（YYYY-MM-DD）
  startedOn: string;
  choice: GoalChoice;
  // 端末が見せていた値。見せる値と違えば決めない
  shown: ShownGoal;
  // 端末が数えた、受け付けなかった自分の目標体重の数。観測にだけ使う
  rejectedCustomTargetWeightCount: number;
};

export type GoalDecision =
  // 決めた（同じ要求の ID の再送を含む）。記録は同期の変更と同じ値で、同じ順
  | { status: "decided"; records: GoalDecisionRecord[] }
  // 開始の日か見せていた値が、見せる値と違った。決めずに新しい案を返す
  | { status: "recalculated"; proposals: GoalProposals }
  // 自分で決めた目標体重を受け付けない。決めずにいちばん近い目標体重を返す
  | {
      status: "custom_target_weight_rejected";
      startedOn: string;
      reason: CustomTargetWeightRejectionReason;
      // その期限に受け付ける目標体重が1つも無いときは無い
      nearestAcceptedTargetWeightKg: number | undefined;
    };

// 目標を決める。そのときの体重の傾向と開始の日で見せる値を出し、端末が見せていた値と同じときだけ、1つのトランザクションで書く。
// usageEvents は、決めたときに PostHog へ送る出来事（再送では空）
export const decideGoal = (
  writeRecordChanges: RecordChangeWriter,
  stores: GoalDecisionStores,
  request: GoalDecisionRequest,
  now: Date,
): GoalDecisionResult =>
  writeRecordChanges(({ addChange }): GoalDecisionResult => {
    const decidedGoal = stores.goal.findByDecisionRequest(request.requestId);
    if (decidedGoal !== undefined) {
      return R.succeed({
        decision: { status: "decided", records: readGoalDecisionRecords(stores, decidedGoal) },
        usageEvents: [],
      });
    }
    return R.pipe(
      R.do(),
      R.bind("basis", () => resolveCompleteGoalSetupBasis(stores, request, now)),
      R.bind("assessment", ({ basis }) => assessGoalDecision(basis, request)),
      R.map(({ basis, assessment }) =>
        match(assessment)
          .returnType<{ decision: GoalDecision; usageEvents: UsageEvent[] }>()
          .with({ status: "recalculated" }, (decision) => ({ decision, usageEvents: [] }))
          .with(
            { status: "custom_target_weight_rejected" },
            ({ status, reason, nearestAcceptedTargetWeightKg }) => ({
              decision: {
                status,
                startedOn: basis.startedOn,
                reason,
                nearestAcceptedTargetWeightKg,
              },
              usageEvents: [],
            }),
          )
          .with({ status: "accepted" }, (accepted) =>
            writeDecidedGoal({ stores, addChange, basis, accepted, request, now }),
          )
          .exhaustive(),
      ),
    );
  });

type GoalDecisionStores = GoalSetupStores & Pick<RecordKindStores, "dailyGuide">;

type GoalDecisionResult = R.Result<
  { decision: GoalDecision; usageEvents: UsageEvent[] },
  GoalSetupRequestRejectedError
>;

// 書いた記録と、PostHog に送る出来事を返す
const writeDecidedGoal = ({
  stores,
  addChange,
  basis,
  accepted,
  request,
  now,
}: {
  stores: GoalDecisionStores;
  addChange: RecordChangeWrites["addChange"];
  basis: CompleteGoalSetupBasis;
  accepted: Extract<GoalDecisionAssessment, { status: "accepted" }>;
  request: GoalDecisionRequest;
  now: Date;
}): { decision: GoalDecision; usageEvents: UsageEvent[] } => {
  // 立て直すときは推定を作らず、出来事には前の値を出どころとして送る
  const { initialExpenditure, observedExpenditureSource } = match(basis.expenditure)
    .with({ source: "current" }, () => ({
      initialExpenditure: undefined,
      observedExpenditureSource: "previous" as const,
    }))
    .with({ source: "back_calculated" }, { source: "formula" }, ({ source, kcal }) => ({
      initialExpenditure: { expenditureKcal: kcal, source },
      observedExpenditureSource: source,
    }))
    .exhaustive();
  const goalId = writeGoalDecision(stores, addChange, {
    requestId: request.requestId,
    goal: {
      startedOn: basis.startedOn,
      startingWeightTrendKg: basis.startingWeightTrend.trendKg,
      targetWeightKg: accepted.targetWeightKg,
      decidedAt: now,
      timeZone: request.timeZone,
      weightChange: accepted.weightChange,
    },
    dailyGuide: accepted.dailyGuide,
    initialExpenditure,
  });
  const goal = stores.goal.find(goalId);
  if (goal === undefined) {
    throw new Error("書いた目標が読めない");
  }
  return {
    decision: { status: "decided", records: readGoalDecisionRecords(stores, goal) },
    usageEvents: [
      {
        name: "goal_decision_recorded",
        direction: match(request.choice)
          .returnType<GoalDirection>()
          .with({ type: "maintain" }, () => "maintain")
          .with({ type: "proposal" }, { type: "custom" }, ({ direction }) => direction)
          .exhaustive(),
        isFirstGoal: basis.currentGoal === undefined,
        chosenPlan: accepted.weightChange?.pacePlan ?? "maintain",
        hadSlowedProposal: accepted.hadSlowedProposal,
        rejectedCustomTargetWeightCount: request.rejectedCustomTargetWeightCount,
        expenditureSource: observedExpenditureSource,
        limitHits: accepted.dailyGuide.limitHits,
      },
    ],
  };
};
