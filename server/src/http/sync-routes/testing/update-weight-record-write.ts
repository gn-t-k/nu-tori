export const updateWeightRecordWrite = (
  recordId: string,
  overrides: { id?: string; weightRecord?: Record<string, unknown> } = {},
): { id: string; type: "update_weight_record"; weightRecord: Record<string, unknown> } => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "update_weight_record",
  weightRecord: {
    id: recordId,
    weightKg: 71.9,
    measuredAt: Date.now(),
    timeZone: "Asia/Tokyo",
    version: 2,
    ...overrides.weightRecord,
  },
});
