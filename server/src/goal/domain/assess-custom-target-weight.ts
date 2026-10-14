import { R } from "@praha/byethrow";
import { countAcceptedDaysToDeadline } from "./count-accepted-days-to-deadline";
import { evaluateCustomTargetWeight } from "./evaluate-custom-target-weight";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import { requireCompleteGoalSetupBasis } from "./require-complete-goal-setup-basis";
import { resolveGoalSetupBasis, type GoalSetupStores } from "./resolve-goal-setup-basis";
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
    resolveGoalSetupBasis(stores, request, now),
    R.andThen(requireCompleteGoalSetupBasis),
    R.andThen(({ startedOn, startingWeightTrend, expenditure }) =>
      R.pipe(
        countAcceptedDaysToDeadline({ startedOn, deadlineOn: request.deadlineOn }),
        R.map((daysFromStartToDeadline) => ({
          startedOn,
          evaluation: evaluateCustomTargetWeight({
            direction: request.direction,
            expenditureKcal: expenditure.kcal,
            startingWeightTrendKg: startingWeightTrend.trendKg,
            daysFromStartToDeadline,
            targetWeightKg: request.targetWeightKg,
          }),
        })),
      ),
    ),
  );
