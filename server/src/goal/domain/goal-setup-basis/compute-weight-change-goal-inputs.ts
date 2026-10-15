import { R } from "@praha/byethrow";
import { countAcceptedDaysToDeadline } from "../accepted-deadline";
import type { GoalSetupRequestRejectedError } from "../goal-setup-request-rejected-error";
import type { CompleteGoalSetupBasis } from "./resolve-complete-goal-setup-basis";
import type { WeightChangeDirection } from "../weight-change-direction";
import type { WeightChangeGoalInputs } from "../weight-change-goal-inputs";

// 計算の元と、選んだ向きと期限から、減量・増量の計算の元を出す。期限が受け付ける幅の外なら断る
export const computeWeightChangeGoalInputs = (
  { startedOn, startingWeightTrend, expenditure }: CompleteGoalSetupBasis,
  { direction, deadlineOn }: { direction: WeightChangeDirection; deadlineOn: string },
): R.Result<WeightChangeGoalInputs, GoalSetupRequestRejectedError> =>
  R.pipe(
    countAcceptedDaysToDeadline({ startedOn, deadlineOn }),
    R.map((daysFromStartToDeadline) => ({
      direction,
      expenditureKcal: expenditure.kcal,
      startingWeightTrendKg: startingWeightTrend.trendKg,
      daysFromStartToDeadline,
    })),
  );
