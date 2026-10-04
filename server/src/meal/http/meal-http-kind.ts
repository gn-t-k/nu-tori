import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { Meal } from "../domain/meal";
import { mealRecordSchema } from "./meal-record-schema";
import { mealWriteSchemas } from "./meal-write-schemas";
import { toMealRecord } from "./to-meal-record";
import { toMealWrite } from "./to-meal-write";

export const mealHttpKind: HttpRecordKind<
  Meal,
  (typeof mealWriteSchemas)[number],
  typeof mealRecordSchema
> = {
  writes: { schemas: mealWriteSchemas, toWrite: toMealWrite },
  keepsDeletionMarks: true,
  recordSchema: mealRecordSchema,
  toRecord: toMealRecord,
};
