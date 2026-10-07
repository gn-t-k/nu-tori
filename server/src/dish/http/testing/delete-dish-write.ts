import { generateRecordId } from "../../../domain/record-id";

export const deleteDishWrite = (
  dishId: string,
  overrides: { id?: string } = {},
): { id: string; type: "delete_dish"; dishId: string } => ({
  id: overrides.id ?? generateRecordId(),
  type: "delete_dish",
  dishId,
});
