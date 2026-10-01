import { match } from "ts-pattern";
import type { PresentRecord } from "../../domain/sync-ledger/current-record";
import type { Dish } from "../domain/dish";

export const toDishChangeResponse = (
  sequence: number,
  current: PresentRecord<Dish>,
  recordId: string,
) =>
  match(current)
    .with({ status: "value" }, ({ value }) => ({
      sequence,
      kind: "dish",
      recordId,
      record: {
        id: value.id,
        mealId: value.mealId,
        name: value.name,
        quantity: value.quantity,
        unit: value.unit,
        positionInMeal: value.positionInMeal,
        version: value.version,
      },
    }))
    .with({ status: "deleted" }, () => ({
      sequence,
      kind: "dish_deletion",
      recordId,
      record: {},
    }))
    .exhaustive();
