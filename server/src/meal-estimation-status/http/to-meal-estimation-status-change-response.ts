import { match } from "ts-pattern";
import type { PresentRecord } from "../../domain/sync-ledger/current-record";
import type { MealEstimationStatus } from "../domain/meal-estimation-status";

export const toMealEstimationStatusChangeResponse = (
  sequence: number,
  current: PresentRecord<MealEstimationStatus>,
  mealId: string,
) =>
  match(current)
    .with({ status: "value" }, ({ value }) => ({
      sequence,
      kind: "meal_estimation_status",
      recordId: mealId,
      record: { mealId, status: value },
    }))
    .with({ status: "deleted" }, () => ({
      sequence,
      kind: "meal_estimation_status_deletion",
      recordId: mealId,
      record: {},
    }))
    .exhaustive();
