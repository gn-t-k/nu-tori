export const createWeightRecordWrite = (
  overrides: { id?: string; weightRecord?: Record<string, unknown> } = {},
): { id: string; type: "create_weight_record"; weightRecord: Record<string, unknown> } => {
  const recordId = crypto.randomUUID();
  return {
    id: overrides.id ?? crypto.randomUUID(),
    type: "create_weight_record",
    weightRecord: {
      id: recordId,
      weightKg: 72.4,
      measuredAt: Date.now(),
      timeZone: "Asia/Tokyo",
      ...overrides.weightRecord,
    },
  };
};
