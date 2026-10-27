import { computeMaintenancePlan } from "../compute-maintenance-plan";
import type { CompleteGoalSetupBasis } from "../goal-setup-basis";

export type MaintenanceOffer = {
  direction: "maintain";
  maintenance: ReturnType<typeof computeMaintenancePlan>;
};

// 維持の見せる値。目標案の要求と目標を決める要求は、どちらもこの値を使い、組み直さない
export const offerMaintenance = ({
  startingWeightTrend,
  expenditure,
}: CompleteGoalSetupBasis): MaintenanceOffer => ({
  direction: "maintain",
  maintenance: computeMaintenancePlan({
    expenditureKcal: expenditure.kcal,
    startingWeightTrendKg: startingWeightTrend.trendKg,
  }),
});
