import { match } from "ts-pattern";
import type { PresentRecord } from "../../domain/sync-ledger/current-record";
import type { Meal } from "../domain/meal";

export const toMealChangeResponse = (
  sequence: number,
  current: PresentRecord<Meal>,
  recordId: string,
) =>
  match(current)
    .with({ status: "value" }, ({ value }) => ({
      sequence,
      kind: "meal",
      recordId,
      record: {
        id: value.id,
        eatenAt: value.eatenAt.getTime(),
        eatenAtUtcOffsetSeconds: value.eatenAtUtcOffsetSeconds,
        sentAt: value.sentAt.getTime(),
        sentTimeZone: value.sentTimeZone,
        entryMethod: value.entryMethod,
        photos: value.photoIds.map((id) => ({ id })),
      },
    }))
    .with({ status: "deleted" }, () => ({
      sequence,
      kind: "meal_deletion",
      recordId,
      record: {},
    }))
    .exhaustive();
