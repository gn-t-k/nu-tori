import { generateRecordId } from "../../../domain/record-id";

export const updateMealWrite = (
  mealId: string,
  eatenAt: number,
  overrides: { id?: string } = {},
): { id: string; type: "update_meal"; mealId: string; eatenAt: number } => ({
  id: overrides.id ?? generateRecordId(),
  type: "update_meal",
  mealId,
  eatenAt,
});
