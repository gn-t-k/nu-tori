import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { WeightTrend } from "../domain/weight-trend";
import { toWeightTrendRecord } from "./to-weight-trend-record";
import { weightTrendRecordSchema } from "./weight-trend-record-schema";

// サーバーだけが書く種類なので、端末からの書き込みは届かない
export const weightTrendHttpKind: HttpRecordKind<
  WeightTrend,
  never,
  typeof weightTrendRecordSchema
> = {
  writes: undefined,
  recordSchema: weightTrendRecordSchema,
  toRecord: toWeightTrendRecord,
};
