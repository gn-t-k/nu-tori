import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { computeAcceptedTargetWeightRange } from "./compute-accepted-target-weight-range";
import { computeGoalProposals } from "./compute-goal-proposals";
import { computeMaintenancePlan } from "./compute-maintenance-plan";
import { computeWeightChangeGoalInputs } from "./compute-weight-change-goal-inputs";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalProposals, GoalProposalsPlan } from "./propose-goals";
import type { CompleteGoalSetupBasis } from "./resolve-complete-goal-setup-basis";

// 出し終えた計算の元から、目標案を出す。目標案の要求と、目標を決める要求が決めずに返す「新しい案」が使う
export const proposeGoalsOnBasis = (
  basis: CompleteGoalSetupBasis,
  plan: GoalProposalsPlan,
): R.Result<GoalProposals, GoalSetupRequestRejectedError> => {
  const { startedOn, startingWeightTrend, expenditure } = basis;
  return R.pipe(
    match(plan)
      .returnType<R.Result<GoalProposals["plan"], GoalSetupRequestRejectedError>>()
      .with({ direction: "maintain" }, ({ direction }) =>
        R.succeed({
          direction,
          maintenance: computeMaintenancePlan({
            expenditureKcal: expenditure.kcal,
            startingWeightTrendKg: startingWeightTrend.trendKg,
          }),
        }),
      )
      .with({ direction: "lose" }, { direction: "gain" }, (weightChangePlan) =>
        R.pipe(
          computeWeightChangeGoalInputs(basis, weightChangePlan),
          R.map((goal) => ({
            direction: weightChangePlan.direction,
            deadlineOn: weightChangePlan.deadlineOn,
            proposals: computeGoalProposals(goal).proposals,
            acceptedTargetWeightRange: computeAcceptedTargetWeightRange(goal),
          })),
        ),
      )
      .exhaustive(),
    R.map((proposed) => ({ startedOn, startingWeightTrend, expenditure, plan: proposed })),
  );
};
