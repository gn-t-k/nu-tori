export const updateIngredientWrite = (
  ingredientId: string,
  quantity: number,
  overrides: { id?: string } = {},
): { id: string; type: "update_ingredient"; ingredientId: string; quantity: number } => ({
  id: overrides.id ?? crypto.randomUUID(),
  type: "update_ingredient",
  ingredientId,
  quantity,
});
