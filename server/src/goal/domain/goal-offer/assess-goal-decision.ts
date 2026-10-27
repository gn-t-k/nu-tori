import { R } from "@praha/byethrow";
import { match } from "ts-pattern";
import type { ComputedDailyGuide } from "../../../daily-guide/domain/computed-daily-guide";
import type { DailyGuideAmounts } from "../../../daily-guide/domain/daily-guide-amounts";
import { moveDeadlineIntoAcceptedRange } from "../accepted-deadline";
import type { CustomTargetWeightRejectionReason } from "../custom-target-weight-rejection-reason";
import type { GoalWeightChange } from "../goal";
import type { CompleteGoalSetupBasis } from "../goal-setup-basis";
import type { GoalSetupRequestRejectedError } from "../goal-setup-request-rejected-error";
import type { ProposalPace } from "../proposal-pace";
import { roundToTenthKg } from "../round-to-tenth-kg";
import type { WeightChangeDirection } from "../weight-change-direction";
import type { GoalProposalsPlan } from "./compute-goal-offer";
import { offerMaintenance } from "./offer-maintenance";
import { offerWeightChange } from "./offer-weight-change";
import { type GoalProposals, proposeGoalsOnBasis } from "./propose-goals-on-basis";

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

// 端末が見せていた値
export type ShownGoal = {
  targetWeightKg: number;
  dailyGuide: DailyGuideAmounts;
};

// 決めるかの判定。決めるなら書く値を持つ
export type GoalDecisionAssessment =
  | {
      status: "accepted";
      targetWeightKg: number;
      dailyGuide: ComputedDailyGuide;
      weightChange: GoalWeightChange | undefined;
      // 1日の目安が下限を下回らないよう、速さを落とした案があったか
      hadSlowedProposal: boolean;
    }
  // 開始の日か見せていた値が、見せる値と違った。決めずに新しい案を返す
  | { status: "recalculated"; proposals: GoalProposals }
  | {
      status: "custom_target_weight_rejected";
      reason: CustomTargetWeightRejectionReason;
      // その期限に受け付ける目標体重が1つも無いときは無い
      nearestAcceptedTargetWeightKg: number | undefined;
    };

// 計算の元と選んだもので見せる値を出し、端末が見せていた値と同じときだけ決める。何も書かない
export const assessGoalDecision = (
  basis: CompleteGoalSetupBasis,
  request: { startedOn: string; choice: GoalChoice; shown: ShownGoal },
): R.Result<GoalDecisionAssessment, GoalSetupRequestRejectedError> => {
  const { choice, shown } = request;
  // 開始の日が違えば、受け付けるかどうかより先に、新しい開始の日の案を見せ直す
  if (basis.startedOn !== request.startedOn) {
    return recalculate(basis, choice);
  }
  return R.pipe(
    findChosen(basis, choice),
    R.andThen((chosen) =>
      match(chosen)
        .returnType<R.Result<GoalDecisionAssessment, GoalSetupRequestRejectedError>>()
        .with({ status: "unavailable" }, () => recalculate(basis, choice))
        .with({ status: "custom_target_weight_rejected" }, (rejected) => R.succeed(rejected))
        .with({ status: "accepted" }, (accepted) =>
          isSameAsShown(accepted, shown) ? R.succeed(accepted) : recalculate(basis, choice),
        )
        .exhaustive(),
    ),
  );
};

type ChosenGoal =
  | Extract<GoalDecisionAssessment, { status: "accepted" | "custom_target_weight_rejected" }>
  // 選んでいた案が出せなくなった
  | { status: "unavailable" };

// 見せる値から、選んだものの値を取り出す。組み直さない
const findChosen = (
  basis: CompleteGoalSetupBasis,
  choice: GoalChoice,
): R.Result<ChosenGoal, GoalSetupRequestRejectedError> =>
  match(choice)
    .returnType<R.Result<ChosenGoal, GoalSetupRequestRejectedError>>()
    .with({ type: "maintain" }, () =>
      R.succeed({
        status: "accepted",
        ...offerMaintenance(basis).maintenance,
        weightChange: undefined,
        hadSlowedProposal: false,
      }),
    )
    .with({ type: "proposal" }, ({ direction, deadlineOn, pace }) =>
      R.pipe(
        offerWeightChange(basis, { direction, deadlineOn }),
        R.map(({ proposals, hadSlowedProposal }): ChosenGoal => {
          const proposal = proposals.find((candidate) => candidate.pace === pace);
          if (proposal === undefined) {
            return { status: "unavailable" };
          }
          return match(proposal)
            .returnType<ChosenGoal>()
            .with({ status: "offered" }, ({ targetWeightKg, dailyGuide }) => ({
              status: "accepted",
              targetWeightKg,
              dailyGuide,
              weightChange: { deadlineOn, pacePlan: pace },
              hadSlowedProposal,
            }))
            .with({ status: "unavailable" }, () => ({ status: "unavailable" }))
            .exhaustive();
        }),
      ),
    )
    .with({ type: "custom" }, ({ direction, deadlineOn, targetWeightKg }) =>
      R.pipe(
        offerWeightChange(basis, { direction, deadlineOn }),
        R.map(({ evaluateCustomTargetWeight, hadSlowedProposal }): ChosenGoal => {
          return match(evaluateCustomTargetWeight(targetWeightKg))
            .returnType<ChosenGoal>()
            .with({ status: "accepted" }, (evaluation) => ({
              status: "accepted",
              targetWeightKg: evaluation.targetWeightKg,
              dailyGuide: evaluation.dailyGuide,
              weightChange: { deadlineOn, pacePlan: "custom" },
              hadSlowedProposal,
            }))
            .with({ status: "rejected" }, ({ reason, nearestAcceptedTargetWeightKg }) => ({
              status: "custom_target_weight_rejected",
              reason,
              nearestAcceptedTargetWeightKg,
            }))
            .exhaustive();
        }),
      ),
    )
    .exhaustive();

const recalculate = (
  basis: CompleteGoalSetupBasis,
  choice: GoalChoice,
): R.Result<GoalDecisionAssessment, GoalSetupRequestRejectedError> => {
  const plan = match(choice)
    .returnType<GoalProposalsPlan>()
    .with({ type: "maintain" }, () => ({ direction: "maintain" }))
    .with({ type: "proposal" }, { type: "custom" }, ({ direction, deadlineOn }) => ({
      direction,
      // 開始の日がずれて期限が受け付ける幅の外に出たら、いちばん近い日に寄せて見せ直す。端末は返った期限を使い直す
      deadlineOn: moveDeadlineIntoAcceptedRange({ startedOn: basis.startedOn, deadlineOn }),
    }))
    .exhaustive();
  return R.pipe(
    proposeGoalsOnBasis(basis, plan),
    R.map((proposals) => ({ status: "recalculated", proposals })),
  );
};

// 目標体重は 0.1 kg 単位、1日の目安は整数で見せているので、その単位で比べる。見せる値の目標体重は 0.1 kg 単位になっている
const isSameAsShown = (
  accepted: Pick<
    Extract<GoalDecisionAssessment, { status: "accepted" }>,
    "targetWeightKg" | "dailyGuide"
  >,
  shown: ShownGoal,
): boolean =>
  accepted.targetWeightKg === roundToTenthKg(shown.targetWeightKg, "round") &&
  accepted.dailyGuide.energyKcal === shown.dailyGuide.energyKcal &&
  accepted.dailyGuide.proteinG === shown.dailyGuide.proteinG &&
  accepted.dailyGuide.fatG === shown.dailyGuide.fatG &&
  accepted.dailyGuide.carbohydrateG === shown.dailyGuide.carbohydrateG;
