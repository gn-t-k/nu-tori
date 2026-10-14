import { R } from "@praha/byethrow";
import { acceptedDeadlineDays } from "./accepted-deadline-days";
import { computeGoalProposals } from "./compute-goal-proposals";
import type { GoalDirection } from "./goal-direction";
import type { GoalSetupRequestRejectedError } from "./goal-setup-request-rejected-error";
import type { GoalSetupSituation } from "./goal-setup-situation";
import type { GoalSetupStores } from "./goal-setup-stores";
import { resolveGoalSetupBasis, type GoalSetupBasis } from "./resolve-goal-setup-basis";

export type GoalSetupPreview = {
  // 初めての目標のときだけ答える。立て直すときは推定を作らないので無い
  canBackCalculate: boolean | undefined;
  // 減量で、推定消費カロリーと開始の日の体重の傾向が出せたときだけ答える。
  // 出せないのは、初めての目標で逆算できず、身体データか体重記録がまだ無いとき
  canOfferLoseProposals: boolean | undefined;
};

// 目標の下見。向きを選んだ直後に、逆算できるかと、減量の目標案を1つでも出せるかを答える。何も書かない
export const previewGoalSetup = (
  stores: GoalSetupStores,
  request: GoalSetupSituation & { direction: GoalDirection },
  now: Date,
): R.Result<GoalSetupPreview, GoalSetupRequestRejectedError> =>
  R.pipe(
    resolveGoalSetupBasis(stores, request, now),
    R.map((basis) => ({
      canBackCalculate:
        basis.currentGoal === undefined
          ? basis.expenditure?.source === "back_calculated"
          : undefined,
      canOfferLoseProposals:
        request.direction === "lose" ? canOfferLoseProposals(basis) : undefined,
    })),
  );

// 期限を選ぶ前に答えるので、受け付けるいちばん短い期限で確かめる。
// 短い期限ほど、1日の目安が下限に当たるまでに落とせる体重が小さく、案を出しにくい。ここで出せれば、あとで選ぶどの期限でも出せる
const canOfferLoseProposals = ({
  startingWeightTrend,
  expenditure,
}: GoalSetupBasis): boolean | undefined =>
  startingWeightTrend === undefined || expenditure === undefined
    ? undefined
    : computeGoalProposals({
        direction: "lose",
        expenditureKcal: expenditure.kcal,
        startingWeightTrendKg: startingWeightTrend.trendKg,
        daysFromStartToDeadline: acceptedDeadlineDays.minimum,
      }).some(({ status }) => status === "offered");
