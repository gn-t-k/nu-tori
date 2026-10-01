import type { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { Meal } from "../domain/meal";
import { mealWriteTypes } from "../domain/meal-write";
import type { mealWriteSchemas } from "./meal-write-schemas";
import { toMealChangeResponse } from "./to-meal-change-response";
import { toMealWrite } from "./to-meal-write";

export const mealHttpKind: HttpRecordKind<Meal, z.infer<(typeof mealWriteSchemas)[number]>> = {
  writeTypes: mealWriteTypes,
  toWrite: toMealWrite,
  toChangeResponse: toMealChangeResponse,
};
