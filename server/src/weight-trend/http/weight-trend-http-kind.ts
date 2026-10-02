import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { WeightTrend } from "../domain/weight-trend";
import { toWeightTrendChangeResponse } from "./to-weight-trend-change-response";

// サーバーだけが書く種類なので、端末からの書き込みは届かない（書き込みの型が never）
export const weightTrendHttpKind: HttpRecordKind<WeightTrend, never> = {
  writeTypes: [],
  toWrite: (write) => write,
  toChangeResponse: toWeightTrendChangeResponse,
};
