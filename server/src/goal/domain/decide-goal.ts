import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { sendsUsageData } from "../../account-settings/domain/sends-usage-data";
import type { ComputedDailyGuide } from "../../daily-guide/domain/computed-daily-guide";
import type { DailyGuideAmounts } from "../../daily-guide/domain/daily-guide-amounts";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordChangeWrites } from "../../domain/record-change-writes";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { UsageEvent } from "../../domain/usage-event";
import { computeGoalProposals } from "./compute-goal-proposals";
import { computeMaintenancePlan } from "./compute-maintenance-plan";
import { computeWeightChangeGoalInputs } from "./compute-weight-change-goal-inputs";
import type { CustomTargetWeightRejectionReason } from "./custom-target-weight-rejection-reason";
import { evaluateCustomTargetWeight } from "./evaluate-custom-target-weight";
import type { GoalWeightChange } from "./goal";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import { moveDeadlineIntoAcceptedRange } from "./accepted-deadline";
import type { ProposalPace } from "./proposal-pace";
import type { GoalProposals, GoalProposalsPlan } from "./propose-goals";
import { proposeGoalsOnBasis } from "./propose-goals-on-basis";
import { type GoalDecisionRecord, readGoalDecisionRecords } from "./read-goal-decision-records";
import {
  type CompleteGoalSetupBasis,
  resolveCompleteGoalSetupBasis,
} from "./resolve-complete-goal-setup-basis";
import type { GoalSetupStores } from "./goal-setup-stores";
import { roundToTenthKg } from "./round-to-tenth-kg";
import type { WeightChangeDirection } from "./weight-change-direction";
import { writeGoalDecision } from "./write-goal-decision";

// 選んだもの。維持、ゆるめ・標準・ハードの案、自分で決めた目標体重のどれか
export type GoalChoice =
  | { type: "maintain" }
  | { type: "proposal"; direction: WeightChangeDirection; deadlineOn: string; pace: ProposalPace }
  | {
      type: "custom";
      direction: WeightChangeDirection;
      deadlineOn: string;
      targetWeightKg: number;
    };

export type GoalDecisionRequest = GoalSetupSituation & {
  // 端末が振った要求の ID。同じ ID の再送は、書かずに初めてと同じ形で答える
  requestId: string;
  // 目標案の応答で受け取った開始の日（YYYY-MM-DD）
  startedOn: string;
  choice: GoalChoice;
  // 端末が見せていた値。計算し直した値と違えば決めない
  shown: {
    targetWeightKg: number;
    dailyGuide: DailyGuideAmounts;
  };
  // 端末が数えた、受け付けなかった自分の目標体重の数。観測にだけ使う
  rejectedCustomTargetWeightCount: number;
};

export type GoalDecision =
  // 決めた（同じ要求の ID の再送を含む）。記録は同期の変更と同じ値で、同じ順
  | { status: "decided"; records: GoalDecisionRecord[] }
  // 開始の日か見せていた値が、計算し直した値と違った。決めずに新しい案を返す
  | { status: "recalculated"; proposals: GoalProposals }
  // 自分で決めた目標体重を受け付けない。決めずにいちばん近い目標体重を返す
  | {
      status: "custom_target_weight_rejected";
      startedOn: string;
      reason: CustomTargetWeightRejectionReason;
      // その期限に受け付ける目標体重が1つも無いときは無い
      nearestAcceptedTargetWeightKg: number | undefined;
    };

// 目標を決める。そのときの体重の傾向と開始の日で計算し直し、端末が見せていた値と同じときだけ、1つのトランザクションで書く。
// usageEvents は、決めたときに PostHog へ送る出来事（利用状況を送らない人と、再送では空）
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
      resolveCompleteGoalSetupBasis(stores, request, now),
      R.andThen((basis) => {
        // 開始の日が違えば、受け付けるかどうかより先に、新しい開始の日の案を見せ直す
        if (basis.startedOn !== request.startedOn) {
          return recalculate(basis, request.choice);
        }
        return R.pipe(
          assessChoice(basis, request.choice),
          R.andThen((assessed) =>
            match(assessed)
              .returnType<GoalDecisionResult>()
              .with({ status: "unavailable" }, () => recalculate(basis, request.choice))
              .with({ status: "rejected" }, ({ reason, nearestAcceptedTargetWeightKg }) =>
                R.succeed({
                  decision: {
                    status: "custom_target_weight_rejected",
                    startedOn: basis.startedOn,
                    reason,
                    nearestAcceptedTargetWeightKg,
                  },
                  usageEvents: [],
                }),
              )
              .with({ status: "accepted" }, (accepted) =>
                isSameAsShown(accepted, request.shown)
                  ? R.succeed(
                      writeDecidedGoal({ stores, addChange, basis, accepted, request, now }),
                    )
                  : recalculate(basis, request.choice),
              )
              .exhaustive(),
          ),
        );
      }),
    );
  });

type GoalDecisionStores = GoalSetupStores &
  Pick<RecordKindStores, "dailyGuide" | "accountSettings">;

type GoalDecisionResult = R.Result<
  { decision: GoalDecision; usageEvents: UsageEvent[] },
  GoalSetupRequestRejectedError
>;

// 選んだものを、そのときの計算の元で確かめた結果
type AssessedChoice =
  | AcceptedChoice
  // 選んでいた案が出せなくなった
  | { status: "unavailable" }
  | {
      status: "rejected";
      reason: CustomTargetWeightRejectionReason;
      nearestAcceptedTargetWeightKg: number | undefined;
    };

type AcceptedChoice = {
  status: "accepted";
  targetWeightKg: number;
  dailyGuide: ComputedDailyGuide;
  weightChange: GoalWeightChange | undefined;
  // 1日の目安が下限を下回らないよう、速さを落とした案があったか
  hadSlowedProposal: boolean;
};

const assessChoice = (
  basis: CompleteGoalSetupBasis,
  choice: GoalChoice,
): R.Result<AssessedChoice, GoalSetupRequestRejectedError> =>
  match(choice)
    .returnType<R.Result<AssessedChoice, GoalSetupRequestRejectedError>>()
    .with({ type: "maintain" }, () =>
      R.succeed({
        status: "accepted",
        ...computeMaintenancePlan({
          expenditureKcal: basis.expenditure.kcal,
          startingWeightTrendKg: basis.startingWeightTrend.trendKg,
        }),
        weightChange: undefined,
        hadSlowedProposal: false,
      }),
    )
    .with({ type: "proposal" }, { type: "custom" }, (weightChangeChoice) =>
      R.pipe(
        computeWeightChangeGoalInputs(basis, weightChangeChoice),
        R.map((goal) => {
          const { deadlineOn } = weightChangeChoice;
          const { proposals, hadSlowedProposal } = computeGoalProposals(goal);
          return match(weightChangeChoice)
            .returnType<AssessedChoice>()
            .with({ type: "proposal" }, ({ pace }) => {
              const proposal = proposals.find((candidate) => candidate.pace === pace);
              return proposal?.status === "offered"
                ? {
                    status: "accepted",
                    targetWeightKg: proposal.targetWeightKg,
                    dailyGuide: proposal.dailyGuide,
                    weightChange: { deadlineOn, pacePlan: pace },
                    hadSlowedProposal,
                  }
                : { status: "unavailable" };
            })
            .with({ type: "custom" }, ({ targetWeightKg }) => {
              const evaluation = evaluateCustomTargetWeight({ ...goal, targetWeightKg });
              return evaluation.status === "accepted"
                ? {
                    status: "accepted",
                    targetWeightKg: roundToTenthKg(targetWeightKg, "round"),
                    dailyGuide: evaluation.dailyGuide,
                    weightChange: { deadlineOn, pacePlan: "custom" },
                    hadSlowedProposal,
                  }
                : evaluation;
            })
            .exhaustive();
        }),
      ),
    )
    .exhaustive();

const recalculate = (basis: CompleteGoalSetupBasis, choice: GoalChoice): GoalDecisionResult => {
  const plan = match(proposalsPlanOf(choice))
    .returnType<GoalProposalsPlan>()
    .with({ direction: "maintain" }, (maintain) => maintain)
    .with({ direction: "lose" }, { direction: "gain" }, ({ direction, deadlineOn }) => ({
      direction,
      // 開始の日がずれて期限が受け付ける幅の外に出たら、いちばん近い日に寄せて見せ直す。端末は返った期限を使い直す
      deadlineOn: moveDeadlineIntoAcceptedRange({ startedOn: basis.startedOn, deadlineOn }),
    }))
    .exhaustive();
  return R.pipe(
    proposeGoalsOnBasis(basis, plan),
    R.map((proposals) => ({ decision: { status: "recalculated", proposals }, usageEvents: [] })),
  );
};

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
  accepted: AcceptedChoice;
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
    usageEvents: sendsUsageData(stores.accountSettings)
      ? [
          {
            name: "goal_decision_recorded",
            direction: proposalsPlanOf(request.choice).direction,
            isFirstGoal: basis.currentGoal === undefined,
            chosenPlan: accepted.weightChange?.pacePlan ?? "maintain",
            hadSlowedProposal: accepted.hadSlowedProposal,
            rejectedCustomTargetWeightCount: request.rejectedCustomTargetWeightCount,
            expenditureSource: observedExpenditureSource,
            limitHits: accepted.dailyGuide.limitHits,
          },
        ]
      : [],
  };
};

// 選んだものの向きと期限。維持は期限を持たない
const proposalsPlanOf = (choice: GoalChoice): GoalProposalsPlan =>
  match(choice)
    .returnType<GoalProposalsPlan>()
    .with({ type: "maintain" }, () => ({ direction: "maintain" }))
    .with({ type: "proposal" }, { type: "custom" }, ({ direction, deadlineOn }) => ({
      direction,
      deadlineOn,
    }))
    .exhaustive();

// 目標体重は 0.1 kg 単位、1日の目安は整数で見せているので、その単位で比べる
const isSameAsShown = (
  accepted: Pick<AcceptedChoice, "targetWeightKg" | "dailyGuide">,
  shown: GoalDecisionRequest["shown"],
): boolean =>
  Math.round(accepted.targetWeightKg * 10) === Math.round(shown.targetWeightKg * 10) &&
  accepted.dailyGuide.energyKcal === shown.dailyGuide.energyKcal &&
  accepted.dailyGuide.proteinG === shown.dailyGuide.proteinG &&
  accepted.dailyGuide.fatG === shown.dailyGuide.fatG &&
  accepted.dailyGuide.carbohydrateG === shown.dailyGuide.carbohydrateG;
