import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { WeightRecord } from "../domain/weight-record";
import { toWeightRecordRecord } from "./to-weight-record-record";
import { toWeightRecordWrite } from "./to-weight-record-write";
import { weightRecordRecordSchema } from "./weight-record-record-schema";
import { weightRecordWriteSchemas } from "./weight-record-write-schemas";

export const weightRecordHttpKind: HttpRecordKind<
  WeightRecord,
  (typeof weightRecordWriteSchemas)[number],
  typeof weightRecordRecordSchema
> = {
  writes: { schemas: weightRecordWriteSchemas, toWrite: toWeightRecordWrite },
  recordSchema: weightRecordRecordSchema,
  toRecord: toWeightRecordRecord,
};
