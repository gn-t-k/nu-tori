import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { MealEstimationStatus } from "../domain/meal-estimation-status";
import { toMealEstimationStatusChangeResponse } from "./to-meal-estimation-status-change-response";

// サーバーだけが書く種類なので、端末からの書き込みは届かない（書き込みの型が never）
export const mealEstimationStatusHttpKind: HttpRecordKind<MealEstimationStatus, never> = {
  writeTypes: [],
  toWrite: (write) => write,
  toChangeResponse: toMealEstimationStatusChangeResponse,
};
