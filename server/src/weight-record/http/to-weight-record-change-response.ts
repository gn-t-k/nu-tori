import type { WeightRecord } from "../domain/weight-record";

export const toWeightRecordChangeResponse = (sequence: number, weightRecord: WeightRecord) => ({
  sequence,
  kind: "weight_record",
  recordId: weightRecord.id,
  record: {
    id: weightRecord.id,
    weightKg: weightRecord.weightKg,
    measuredAt: weightRecord.measuredAt.getTime(),
    timeZone: weightRecord.timeZone,
    version: weightRecord.version,
    imported: weightRecord.imported,
  },
});

export const toWeightRecordDeletionChangeResponse = (sequence: number, recordId: string) => ({
  sequence,
  kind: "weight_record_deletion",
  recordId,
  record: {},
});
