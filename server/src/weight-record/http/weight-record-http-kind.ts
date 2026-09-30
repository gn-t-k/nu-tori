import type { z } from "@hono/zod-openapi";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { WeightRecord } from "../domain/weight-record";
import { weightRecordWriteTypes } from "../domain/weight-record-write";
import { toWeightRecordChangeResponse } from "./to-weight-record-change-response";
import { toWeightRecordWrite } from "./to-weight-record-write";
import type { weightRecordWriteSchemas } from "./weight-record-write-schemas";

export const weightRecordHttpKind: HttpRecordKind<
  WeightRecord,
  z.infer<(typeof weightRecordWriteSchemas)[number]>
> = {
  writeTypes: weightRecordWriteTypes,
  toWrite: toWeightRecordWrite,
  toChangeResponse: toWeightRecordChangeResponse,
};
