import { R } from "@praha/byethrow";
import { computeWeightChangeGoalInputs } from "./compute-weight-change-goal-inputs";
import { evaluateCustomTargetWeight } from "./evaluate-custom-target-weight";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import { resolveCompleteGoalSetupBasis } from "./resolve-complete-goal-setup-basis";
import type { GoalSetupStores } from "./resolve-goal-setup-basis";
import type { WeightChangeDirection } from "./weight-change-direction";

export type CustomTargetWeightAssessment = {
  // 計算に使った開始の日（YYYY-MM-DD）
  startedOn: string;
  evaluation: ReturnType<typeof evaluateCustomTargetWeight>;
};

// 自分で決める目標体重。受け付けるなら1日の目安と大変さを、受け付けないならいちばん近い目標体重と理由を答える。何も書かない
export const assessCustomTargetWeight = (
  stores: GoalSetupStores,
  request: GoalSetupSituation & {
    direction: WeightChangeDirection;
    deadlineOn: string;
    targetWeightKg: number;
  },
  now: Date,
): R.Result<CustomTargetWeightAssessment, GoalSetupRequestRejectedError> =>
  R.pipe(
    resolveCompleteGoalSetupBasis(stores, request, now),
    R.andThen((basis) =>
      R.pipe(
        computeWeightChangeGoalInputs(basis, request),
        R.map((goal) => ({
          startedOn: basis.startedOn,
          evaluation: evaluateCustomTargetWeight({
            ...goal,
            targetWeightKg: request.targetWeightKg,
          }),
        })),
      ),
    ),
  );
