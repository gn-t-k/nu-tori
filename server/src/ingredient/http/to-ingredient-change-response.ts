import { match } from "ts-pattern";
import type { PresentRecord } from "../../domain/sync-ledger/current-record";
import type { Ingredient } from "../domain/ingredient";

export const toIngredientChangeResponse = (
  sequence: number,
  current: PresentRecord<Ingredient>,
  recordId: string,
) =>
  match(current)
    .with({ status: "value" }, ({ value }) => ({
      sequence,
      kind: "ingredient",
      recordId,
      record: {
        id: value.id,
        dishId: value.dishId,
        name: value.name,
        quantity: value.quantity,
        unit: value.unit,
        edibleGramsPerUnit: value.edibleGramsPerUnit,
        positionInDish: value.positionInDish,
        nutrientSource: value.nutrientSource,
        // 項目の名前は shared/nutrients.json。不明の項目はキーを持たない
        nutrients: value.nutrients,
      },
    }))
    .with({ status: "deleted" }, () => ({
      sequence,
      kind: "ingredient_deletion",
      recordId,
      record: {},
    }))
    .exhaustive();
