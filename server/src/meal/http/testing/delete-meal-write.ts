export const deleteMealWrite = (
  mealId: string,
  overrides: { id?: string } = {},
): { id: string; type: "delete_meal"; mealId: string } => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "delete_meal",
  mealId,
});
