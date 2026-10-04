import type { Dish } from "../domain/dish";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { dishRecordSchema } from "./dish-record-schema";
import { toDishRecord } from "./to-dish-record";

// サーバーだけが書く種類なので、端末からの書き込みは届かない
export const dishHttpKind: HttpRecordKind<Dish, never, typeof dishRecordSchema> = {
  writes: undefined,
  recordSchema: dishRecordSchema,
  toRecord: toDishRecord,
};
