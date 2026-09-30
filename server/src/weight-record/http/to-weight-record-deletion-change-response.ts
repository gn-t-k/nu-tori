export const toWeightRecordDeletionChangeResponse = (sequence: number, recordId: string) => ({
  sequence,
  kind: "weight_record_deletion",
  recordId,
  record: {},
});
