import { R } from "@praha/byethrow";
import type { GoalSetupExpenditure } from "./goal-setup-expenditure";
import { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import {
  resolveGoalSetupBasis,
  type GoalSetupBasis,
  type GoalSetupStores,
  type StartingWeightTrend,
} from "./resolve-goal-setup-basis";

// 目標案から先の計算に要る値が揃った、計算の元
export type CompleteGoalSetupBasis = Pick<GoalSetupBasis, "startedOn" | "currentGoal"> & {
  startingWeightTrend: StartingWeightTrend;
  expenditure: GoalSetupExpenditure;
};

// 目標案から先の要求の計算の元を出し、体重記録と推定消費カロリーが揃っていることを確かめる。
// 端末は、体重記録を送り切り、逆算できない人の身体データを添えてから目標案の要求を出すので、揃っていないのは不具合のときだけ
export const resolveCompleteGoalSetupBasis = (
  stores: GoalSetupStores,
  situation: GoalSetupSituation,
  now: Date,
): R.Result<CompleteGoalSetupBasis, GoalSetupRequestRejectedError> =>
  R.pipe(
    resolveGoalSetupBasis(stores, situation, now),
    R.andThen(({ startedOn, currentGoal, startingWeightTrend, expenditure }) => {
      if (startingWeightTrend === undefined) {
        return R.fail(new GoalSetupRequestRejectedError({ reason: "weight_record_missing" }));
      }
      if (expenditure === undefined) {
        return R.fail(new GoalSetupRequestRejectedError({ reason: "body_data_missing" }));
      }
      return R.succeed({ startedOn, currentGoal, startingWeightTrend, expenditure });
    }),
  );
