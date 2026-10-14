import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import { computeAcceptedTargetWeightRange } from "./compute-accepted-target-weight-range";
import { computeGoalProposals } from "./compute-goal-proposals";
import { computeMaintenancePlan } from "./compute-maintenance-plan";
import { countAcceptedDaysToDeadline } from "./count-accepted-days-to-deadline";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import {
  requireCompleteGoalSetupBasis,
  type CompleteGoalSetupBasis,
} from "./require-complete-goal-setup-basis";
import { resolveGoalSetupBasis, type GoalSetupStores } from "./resolve-goal-setup-basis";
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
        proposals: ReturnType<typeof computeGoalProposals>;
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
    resolveGoalSetupBasis(stores, request, now),
    R.andThen(requireCompleteGoalSetupBasis),
    R.andThen(({ startedOn, startingWeightTrend, expenditure }) =>
      R.pipe(
        match(request.plan)
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
          .with({ direction: "lose" }, { direction: "gain" }, ({ direction, deadlineOn }) =>
            R.pipe(
              countAcceptedDaysToDeadline({ startedOn, deadlineOn }),
              R.map((daysFromStartToDeadline) => {
                const goal = {
                  direction,
                  expenditureKcal: expenditure.kcal,
                  startingWeightTrendKg: startingWeightTrend.trendKg,
                  daysFromStartToDeadline,
                };
                return {
                  direction,
                  deadlineOn,
                  proposals: computeGoalProposals(goal),
                  acceptedTargetWeightRange: computeAcceptedTargetWeightRange(goal),
                };
              }),
            ),
          )
          .exhaustive(),
        R.map((plan) => ({ startedOn, startingWeightTrend, expenditure, plan })),
      ),
    ),
  );
