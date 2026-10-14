import { R } from "@praha/byethrow";
import type { computeAcceptedTargetWeightRange } from "./compute-accepted-target-weight-range";
import type { GoalProposal } from "./compute-goal-proposals";
import type { computeMaintenancePlan } from "./compute-maintenance-plan";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import { proposeGoalsOnBasis } from "./propose-goals-on-basis";
import {
  resolveCompleteGoalSetupBasis,
  type CompleteGoalSetupBasis,
} from "./resolve-complete-goal-setup-basis";
import type { GoalSetupStores } from "./goal-setup-stores";
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

// 目標案。そのときの体重の傾向と開始の日で計算し、何も書かない
export const proposeGoals = (
  stores: GoalSetupStores,
  request: GoalSetupSituation & { plan: GoalProposalsPlan },
  now: Date,
): R.Result<GoalProposals, GoalSetupRequestRejectedError> =>
  R.pipe(
    resolveCompleteGoalSetupBasis(stores, request, now),
    R.andThen((basis) => proposeGoalsOnBasis(basis, request.plan)),
  );
