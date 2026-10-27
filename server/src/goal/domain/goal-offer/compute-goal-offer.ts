import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import type { CompleteGoalSetupBasis } from "../goal-setup-basis";
import type { GoalSetupRequestRejectedError } from "../goal-setup-request-rejected-error";
import type { WeightChangeDirection } from "../weight-change-direction";
import { type MaintenanceOffer, offerMaintenance } from "./offer-maintenance";
import { offerWeightChange, type WeightChangeOffer } from "./offer-weight-change";

// 選んだ向きと期限。維持は期限を持たない
export type GoalProposalsPlan =
  | { direction: "maintain" }
  | { direction: WeightChangeDirection; deadlineOn: string };

// 向きと期限の見せる値と、計算に使った計算の元
export type GoalOffer = Pick<
  CompleteGoalSetupBasis,
  "startedOn" | "startingWeightTrend" | "expenditure"
> & { plan: MaintenanceOffer | WeightChangeOffer };

// 出し終えた計算の元と、選んだ向きと期限から、見せる値を出す。期限が受け付ける幅の外なら断る
export const computeGoalOffer = (
  basis: CompleteGoalSetupBasis,
  plan: GoalProposalsPlan,
): R.Result<GoalOffer, GoalSetupRequestRejectedError> => {
  const { startedOn, startingWeightTrend, expenditure } = basis;
  return R.pipe(
    match(plan)
      .returnType<R.Result<GoalOffer["plan"], GoalSetupRequestRejectedError>>()
      .with({ direction: "maintain" }, () => R.succeed(offerMaintenance(basis)))
      .with({ direction: "lose" }, { direction: "gain" }, (weightChangePlan) =>
        offerWeightChange(basis, weightChangePlan),
      )
      .exhaustive(),
    R.map((offered) => ({ startedOn, startingWeightTrend, expenditure, plan: offered })),
  );
};
