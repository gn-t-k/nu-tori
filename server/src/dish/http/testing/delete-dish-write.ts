export const deleteDishWrite = (
  dishId: string,
  overrides: { id?: string } = {},
): { id: string; type: "delete_dish"; dishId: string } => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "delete_dish",
  dishId,
});
