import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { SentText } from "../domain/sent-text";
import { sentTextRecordSchema } from "./sent-text-record-schema";
import { sentTextWriteSchemas } from "./sent-text-write-schemas";
import { toSentTextRecord } from "./to-sent-text-record";
import { toSentTextWrite } from "./to-sent-text-write";

export const sentTextHttpKind: HttpRecordKind<
  SentText,
  (typeof sentTextWriteSchemas)[number],
  typeof sentTextRecordSchema
> = {
  writes: { schemas: sentTextWriteSchemas, toWrite: toSentTextWrite },
  recordSchema: sentTextRecordSchema,
  toRecord: toSentTextRecord,
};
