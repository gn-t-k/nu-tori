import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { sendsUsageData } from "../../account-settings/domain/sends-usage-data";
import type { computeDailyGuide } from "../../daily-guide/domain/compute-daily-guide";
import type { RecordChangeWriter } from "../../domain/record-change-writer";
import type { RecordKindStores } from "../../domain/record-kind-stores";
import type { UsageEvent } from "../../domain/usage-event";
import { computeGoalProposals } from "./compute-goal-proposals";
import { computeMaintenancePlan } from "./compute-maintenance-plan";
import { computeTargetWeightLimits } from "./compute-target-weight-limits";
import { countAcceptedDaysToDeadline } from "./count-accepted-days-to-deadline";
import { evaluateCustomTargetWeight } from "./evaluate-custom-target-weight";
import type { GoalWeightChange } from "./goal";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import type { ProposalPace } from "./proposal-pace";
import type { GoalProposals } from "./propose-goals";
import { proposeGoalsOnBasis } from "./propose-goals-on-basis";
import { type GoalDecisionRecord, readGoalDecisionRecords } from "./read-goal-decision-records";
import {
  type CompleteGoalSetupBasis,
  requireCompleteGoalSetupBasis,
} from "./require-complete-goal-setup-basis";
import { resolveGoalSetupBasis, type GoalSetupStores } from "./resolve-goal-setup-basis";
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
    dailyGuide: { energyKcal: number; proteinG: number; fatG: number; carbohydrateG: number };
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
      reason: "not_on_direction_side" | "pace_too_fast" | "daily_guide_below_minimum";
      // その期限に受け付ける目標体重が1つも無いときは無い
      nearestAcceptedTargetWeightKg: number | undefined;
    };

// 目標を決める。そのときの体重の傾向と開始の日で計算し直し、端末が見せていた値と同じときだけ、1つのトランザクションで書く。
// usageEvents は、決めたときに PostHog へ送る出来事（利用状況を送らない人と、再送では空）
export const decideGoal = (
  writeRecordChanges: RecordChangeWriter,
  stores: GoalSetupStores & Pick<RecordKindStores, "dailyGuide" | "accountSettings">,
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
      resolveGoalSetupBasis(stores, request, now),
      R.andThen(requireCompleteGoalSetupBasis),
      R.andThen((basis) =>
        R.pipe(
          assessChoice(basis, request.choice),
          R.andThen((assessed) => {
            // 開始の日が違えば、受け付けるかどうかより先に、新しい開始の日の案を見せ直す
            if (basis.startedOn !== request.startedOn) {
              return recalculate(basis, request.choice);
            }
            return match(assessed)
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
              .with({ status: "accepted" }, (accepted) => {
                if (!isSameAsShown(accepted, request.shown)) {
                  return recalculate(basis, request.choice);
                }
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
                  initialExpenditure:
                    basis.expenditure.source === "current"
                      ? undefined
                      : {
                          expenditureKcal: basis.expenditure.kcal,
                          source: basis.expenditure.source,
                        },
                });
                const goal = stores.goal.find(goalId);
                if (goal === undefined) {
                  throw new Error("書いた目標が読めない");
                }
                return R.succeed({
                  decision: { status: "decided", records: readGoalDecisionRecords(stores, goal) },
                  usageEvents: sendsUsageData(stores.accountSettings)
                    ? [
                        {
                          name: "goal_decision_recorded",
                          direction:
                            request.choice.type === "maintain"
                              ? "maintain"
                              : request.choice.direction,
                          isFirstGoal: basis.currentGoal === undefined,
                          chosenPlan: accepted.weightChange?.pacePlan ?? "maintain",
                          hadSlowedProposal: accepted.hadSlowedProposal,
                          rejectedCustomTargetWeightCount: request.rejectedCustomTargetWeightCount,
                          expenditureSource:
                            basis.expenditure.source === "current"
                              ? "previous"
                              : basis.expenditure.source,
                          limitHits: accepted.dailyGuide.limitHits,
                        },
                      ]
                    : [],
                });
              })
              .exhaustive();
          }),
        ),
      ),
    );
  });

type GoalDecisionResult = R.Result<
  { decision: GoalDecision; usageEvents: UsageEvent[] },
  GoalSetupRequestRejectedError
>;

// 選んだものを、そのときの計算の元で確かめた結果
type AssessedChoice =
  | {
      status: "accepted";
      targetWeightKg: number;
      dailyGuide: ReturnType<typeof computeDailyGuide>;
      weightChange: GoalWeightChange | undefined;
      // 1日の目安が下限を下回らないよう、速さを落とした案があったか
      hadSlowedProposal: boolean;
    }
  // 選んでいた案が出せなくなった
  | { status: "unavailable" }
  | {
      status: "rejected";
      reason: "not_on_direction_side" | "pace_too_fast" | "daily_guide_below_minimum";
      nearestAcceptedTargetWeightKg: number | undefined;
    };

const assessChoice = (
  { startedOn, startingWeightTrend, expenditure }: CompleteGoalSetupBasis,
  choice: GoalChoice,
): R.Result<AssessedChoice, GoalSetupRequestRejectedError> => {
  const basisValues = {
    expenditureKcal: expenditure.kcal,
    startingWeightTrendKg: startingWeightTrend.trendKg,
  };
  return match(choice)
    .returnType<R.Result<AssessedChoice, GoalSetupRequestRejectedError>>()
    .with({ type: "maintain" }, () =>
      R.succeed({
        status: "accepted",
        ...computeMaintenancePlan(basisValues),
        weightChange: undefined,
        hadSlowedProposal: false,
      }),
    )
    .with({ type: "proposal" }, { type: "custom" }, (weightChangeChoice) => {
      const { direction, deadlineOn } = weightChangeChoice;
      return R.pipe(
        countAcceptedDaysToDeadline({ startedOn, deadlineOn }),
        R.map((daysFromStartToDeadline) => {
          const goal = { direction, ...basisValues, daysFromStartToDeadline };
          // ハード案がいちばん速いので、速さを落とした案があれば、いちばん速い端は下限で決まっている
          const hadSlowedProposal =
            computeTargetWeightLimits(goal).fastestEndReason === "daily_guide_below_minimum";
          return match(weightChangeChoice)
            .returnType<AssessedChoice>()
            .with({ type: "proposal" }, ({ pace }) => {
              const proposal = computeGoalProposals(goal).find(
                (candidate) => candidate.pace === pace,
              );
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
      );
    })
    .exhaustive();
};

const recalculate = (basis: CompleteGoalSetupBasis, choice: GoalChoice): GoalDecisionResult =>
  R.pipe(
    proposeGoalsOnBasis(
      basis,
      choice.type === "maintain"
        ? { direction: "maintain" }
        : { direction: choice.direction, deadlineOn: choice.deadlineOn },
    ),
    R.map((proposals) => ({ decision: { status: "recalculated", proposals }, usageEvents: [] })),
  );

// 目標体重は 0.1 kg 単位、1日の目安は整数で見せているので、その単位で比べる
const isSameAsShown = (
  accepted: Pick<Extract<AssessedChoice, { status: "accepted" }>, "targetWeightKg" | "dailyGuide">,
  shown: GoalDecisionRequest["shown"],
): boolean =>
  Math.round(accepted.targetWeightKg * 10) === Math.round(shown.targetWeightKg * 10) &&
  accepted.dailyGuide.energyKcal === shown.dailyGuide.energyKcal &&
  accepted.dailyGuide.proteinG === shown.dailyGuide.proteinG &&
  accepted.dailyGuide.fatG === shown.dailyGuide.fatG &&
  accepted.dailyGuide.carbohydrateG === shown.dailyGuide.carbohydrateG;
