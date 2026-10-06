import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { DishEstimationStatus } from "../domain/dish-estimation-status";
import { dishEstimationStatusRecordSchema } from "./dish-estimation-status-record-schema";
import { toDishEstimationStatusRecord } from "./to-dish-estimation-status-record";

// サーバーだけが書く種類なので、端末からの書き込みは届かない
export const dishEstimationStatusHttpKind: HttpRecordKind<
  DishEstimationStatus,
  never,
  typeof dishEstimationStatusRecordSchema
> = {
  writes: undefined,
  recordSchema: dishEstimationStatusRecordSchema,
  toRecord: toDishEstimationStatusRecord,
};
