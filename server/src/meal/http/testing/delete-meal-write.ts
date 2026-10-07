import { generateRecordId } from "../../../domain/record-id";

export const deleteMealWrite = (
  mealId: string,
  overrides: { id?: string } = {},
): { id: string; type: "delete_meal"; mealId: string } => ({
  id: overrides.id ?? generateRecordId(),
  type: "delete_meal",
  mealId,
});
