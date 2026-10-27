import { R } from "@praha/byethrow";
import { resolveCompleteGoalSetupBasis } from "./goal-setup-basis";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import type { GoalSetupStores } from "./goal-setup-stores";
import { proposeGoalsOnBasis, type GoalProposals, type GoalProposalsPlan } from "./goal-offer";

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
