import { match } from "ts-pattern";
import type { PresentRecord } from "../../domain/sync-ledger/current-record";
import type { WeightRecord } from "../domain/weight-record";

export const toWeightRecordChangeResponse = (
  sequence: number,
  current: PresentRecord<WeightRecord>,
  recordId: string,
) =>
  match(current)
    .with({ status: "value" }, ({ value }) => ({
      sequence,
      kind: "weight_record",
      recordId: value.id,
      record: {
        id: value.id,
        weightKg: value.weightKg,
        measuredAt: value.measuredAt.getTime(),
        timeZone: value.timeZone,
        version: value.version,
        imported: value.imported,
      },
    }))
    .with({ status: "deleted" }, () => ({
      sequence,
      kind: "weight_record_deletion",
      recordId,
      record: {},
    }))
    .exhaustive();
