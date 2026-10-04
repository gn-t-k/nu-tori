import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { UsualWeighingTime } from "../domain/usual-weighing-time";
import { toUsualWeighingTimeRecord } from "./to-usual-weighing-time-record";
import { usualWeighingTimeRecordSchema } from "./usual-weighing-time-record-schema";

// サーバーだけが書く種類なので、端末からの書き込みは届かない
export const usualWeighingTimeHttpKind: HttpRecordKind<
  UsualWeighingTime,
  never,
  typeof usualWeighingTimeRecordSchema
> = {
  writes: undefined,
  recordSchema: usualWeighingTimeRecordSchema,
  toRecord: toUsualWeighingTimeRecord,
};
