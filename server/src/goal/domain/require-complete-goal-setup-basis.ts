import { R } from "@praha/byethrow";
import type { GoalSetupExpenditure } from "./goal-setup-expenditure";
import { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupBasis, StartingWeightTrend } from "./resolve-goal-setup-basis";

// 目標案から先の計算に要る値が揃った、計算の元
export type CompleteGoalSetupBasis = Pick<GoalSetupBasis, "startedOn" | "currentGoal"> & {
  startingWeightTrend: StartingWeightTrend;
  expenditure: GoalSetupExpenditure;
};

// 端末は、体重記録を送り切り、逆算できない人の身体データを添えてから目標案の要求を出すので、揃っていないのは不具合のときだけ
export const requireCompleteGoalSetupBasis = ({
  startedOn,
  currentGoal,
  startingWeightTrend,
  expenditure,
}: GoalSetupBasis): R.Result<CompleteGoalSetupBasis, GoalSetupRequestRejectedError> => {
  if (startingWeightTrend === undefined) {
    return R.fail(new GoalSetupRequestRejectedError({ reason: "weight_record_missing" }));
  }
  if (expenditure === undefined) {
    return R.fail(new GoalSetupRequestRejectedError({ reason: "body_data_missing" }));
  }
  return R.succeed({ startedOn, currentGoal, startingWeightTrend, expenditure });
};
