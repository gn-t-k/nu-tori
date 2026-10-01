export const sourceDeletedWeightRecordWrite = (
  weightRecordId: string,
  overrides: { id?: string } = {},
): { id: string; type: "source_deleted_weight_record"; weightRecordId: string } => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "source_deleted_weight_record",
  weightRecordId,
});
