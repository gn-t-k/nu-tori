import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { computeAcceptedTargetWeightRange } from "./compute-accepted-target-weight-range";
import { computeGoalProposals, type GoalProposal } from "./compute-goal-proposals";
import { computeMaintenancePlan } from "./compute-maintenance-plan";
import { type CompleteGoalSetupBasis, computeWeightChangeGoalInputs } from "./goal-setup-basis";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { WeightChangeDirection } from "./weight-change-direction";

// 選んだ向きと期限。維持は期限を持たない
export type GoalProposalsPlan =
  | { direction: "maintain" }
  | { direction: WeightChangeDirection; deadlineOn: string };

// 目標案の答え。目標を決める要求が決めずに返す「新しい案」も、この形
export type GoalProposals = Pick<
  CompleteGoalSetupBasis,
  "startedOn" | "startingWeightTrend" | "expenditure"
> & {
  plan:
    | { direction: "maintain"; maintenance: ReturnType<typeof computeMaintenancePlan> }
    | {
        direction: WeightChangeDirection;
        deadlineOn: string;
        // ゆるめ・標準・ハードの3つの枠を、いつもこの順に持つ
        proposals: GoalProposal[];
        // 自分で決める目標体重の受け付ける幅。受け付ける目標体重が1つも無いときは無い
        acceptedTargetWeightRange: ReturnType<typeof computeAcceptedTargetWeightRange>;
      };
};

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
