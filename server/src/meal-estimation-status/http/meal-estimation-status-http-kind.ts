import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { MealEstimationStatus } from "../domain/meal-estimation-status";
import { mealEstimationStatusRecordSchema } from "./meal-estimation-status-record-schema";
import { toMealEstimationStatusRecord } from "./to-meal-estimation-status-record";

// サーバーだけが書く種類なので、端末からの書き込みは届かない
export const mealEstimationStatusHttpKind: HttpRecordKind<
  MealEstimationStatus,
  never,
  typeof mealEstimationStatusRecordSchema
> = {
  writes: undefined,
  keepsDeletionMarks: true,
  recordSchema: mealEstimationStatusRecordSchema,
  toRecord: toMealEstimationStatusRecord,
};
