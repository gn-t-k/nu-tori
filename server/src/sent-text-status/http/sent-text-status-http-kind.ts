import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { SentTextStatus } from "../domain/sent-text-status";
import { sentTextStatusRecordSchema } from "./sent-text-status-record-schema";
import { toSentTextStatusRecord } from "./to-sent-text-status-record";

// サーバーだけが書く種類なので、端末からの書き込みは届かない
export const sentTextStatusHttpKind: HttpRecordKind<
  SentTextStatus,
  never,
  typeof sentTextStatusRecordSchema
> = {
  writes: undefined,
  recordSchema: sentTextStatusRecordSchema,
  toRecord: toSentTextStatusRecord,
};
