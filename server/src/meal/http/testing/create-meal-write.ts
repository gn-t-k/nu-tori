export const createMealWrite = (
  overrides: { id?: string; meal?: Record<string, unknown> } = {},
): { id: string; type: "create_meal"; meal: Record<string, unknown> } => {
  const sentAt = Date.now();
  return {
    id: overrides.id ?? crypto.randomUUID(),
    type: "create_meal",
    meal: {
      id: crypto.randomUUID(),
      eatenAt: sentAt - 60_000,
      eatenAtUtcOffsetSeconds: 32_400,
      sentAt,
      sentTimeZone: "Asia/Tokyo",
      entryMethod: "captured",
      photos: [{ id: crypto.randomUUID() }],
      ...overrides.meal,
    },
  };
};
