import { R } from "@praha/byethrow";
import { computeAcceptedTargetWeightRange } from "../compute-accepted-target-weight-range";
import { computeGoalProposals, type GoalProposal } from "../compute-goal-proposals";
import { evaluateCustomTargetWeight } from "../evaluate-custom-target-weight";
import { type CompleteGoalSetupBasis, computeWeightChangeGoalInputs } from "../goal-setup-basis";
import type { GoalSetupRequestRejectedError } from "../goal-setup-request-rejected-error";
import type { WeightChangeDirection } from "../weight-change-direction";

export type WeightChangeOffer = {
  direction: WeightChangeDirection;
  deadlineOn: string;
  // ゆるめ・標準・ハードの3つの枠を、いつもこの順に持つ
  proposals: GoalProposal[];
  // 自分で決める目標体重の受け付ける幅。受け付ける目標体重が1つも無いときは無い
  acceptedTargetWeightRange: ReturnType<typeof computeAcceptedTargetWeightRange>;
  // 1日の目安が下限を下回らないよう、速さを落とした案があったか
  hadSlowedProposal: boolean;
  // 自分で決めた目標体重を、同じ向きと期限で評価する
  evaluateCustomTargetWeight: (
    targetWeightKg: number,
  ) => ReturnType<typeof evaluateCustomTargetWeight>;
};

// 減量・増量の見せる値。期限が受け付ける幅の外なら断る。
// 目標案・自分で決める目標体重・目標を決める要求の3つの入口は、どれもこの値を使い、組み直さない
export const offerWeightChange = (
  basis: CompleteGoalSetupBasis,
  plan: { direction: WeightChangeDirection; deadlineOn: string },
): R.Result<WeightChangeOffer, GoalSetupRequestRejectedError> =>
  R.pipe(
    computeWeightChangeGoalInputs(basis, plan),
    R.map((goal) => {
      const { proposals, hadSlowedProposal } = computeGoalProposals(goal);
      return {
        direction: plan.direction,
        deadlineOn: plan.deadlineOn,
        proposals,
        acceptedTargetWeightRange: computeAcceptedTargetWeightRange(goal),
        hadSlowedProposal,
        evaluateCustomTargetWeight: (targetWeightKg: number) =>
          evaluateCustomTargetWeight({ ...goal, targetWeightKg }),
      };
    }),
  );
