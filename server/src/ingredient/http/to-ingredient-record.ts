import type { z } from "@hono/zod-openapi";
import type { Ingredient } from "../domain/ingredient";
import type { ingredientRecordSchema } from "./ingredient-record-schema";

export const toIngredientRecord = (value: Ingredient): z.input<typeof ingredientRecordSchema> => ({
  id: value.id,
  dishId: value.dishId,
  name: value.name,
  quantity: value.quantity,
  quantitySource: value.quantitySource,
  unit: value.unit,
  edibleGramsPerUnit: value.edibleGramsPerUnit,
  positionInDish: value.positionInDish,
  nutrientSource: value.nutrientSource,
  nutrients: value.nutrients,
});
