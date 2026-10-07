import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { Ingredient } from "../domain/ingredient";
import { ingredientRecordSchema } from "./ingredient-record-schema";
import { ingredientWriteSchemas } from "./ingredient-write-schemas";
import { toIngredientRecord } from "./to-ingredient-record";
import { toIngredientWrite } from "./to-ingredient-write";

export const ingredientHttpKind: HttpRecordKind<
  Ingredient,
  (typeof ingredientWriteSchemas)[number],
  typeof ingredientRecordSchema
> = {
  writes: { schemas: ingredientWriteSchemas, toWrite: toIngredientWrite },
  recordSchema: ingredientRecordSchema,
  toRecord: toIngredientRecord,
};
