import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import type { CompleteGoalSetupBasis } from "../goal-setup-basis";
import type { GoalSetupRequestRejectedError } from "../goal-setup-request-rejected-error";
import type { WeightChangeDirection } from "../weight-change-direction";
import { computeGoalOffer, type GoalOffer, type GoalProposalsPlan } from "./compute-goal-offer";
import type { MaintenanceOffer } from "./offer-maintenance";
import type { WeightChangeOffer } from "./offer-weight-change";

// 目標案の答え。目標を決める要求が決めずに返す「新しい案」も、この形。
// Durable Object の RPC を越えるので、見せる値から値だけを写す
export type GoalProposals = Omit<GoalOffer, "plan"> & {
  plan:
    | MaintenanceOffer
    | ({ direction: WeightChangeDirection } & Pick<
        WeightChangeOffer,
        "deadlineOn" | "proposals" | "acceptedTargetWeightRange"
      >);
};

// 出し終えた計算の元から、目標案を出す。目標案の要求と、目標を決める要求が決めずに返す「新しい案」が使う
export const proposeGoalsOnBasis = (
  basis: CompleteGoalSetupBasis,
  plan: GoalProposalsPlan,
): R.Result<GoalProposals, GoalSetupRequestRejectedError> =>
  R.pipe(
    computeGoalOffer(basis, plan),
    R.map(({ plan: offered, ...measured }) => ({
      ...measured,
      plan: match(offered)
        .returnType<GoalProposals["plan"]>()
        .with({ direction: "maintain" }, (maintain) => maintain)
        .with(
          { direction: "lose" },
          { direction: "gain" },
          ({ direction, deadlineOn, proposals, acceptedTargetWeightRange }) => ({
            direction,
            deadlineOn,
            proposals,
            acceptedTargetWeightRange,
          }),
        )
        .exhaustive(),
    })),
  );
