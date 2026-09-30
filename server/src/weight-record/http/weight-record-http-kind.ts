import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { WeightRecord } from "../domain/weight-record";
import { toWeightRecordChangeResponse } from "./to-weight-record-change-response";
import { toWeightRecordDeletionChangeResponse } from "./to-weight-record-deletion-change-response";
import { toCreateWeightRecordWrite } from "./to-create-weight-record-write";
import { toSourceDeletedWeightRecordWrite } from "./to-source-deleted-weight-record-write";
import { toUpdateWeightRecordWrite } from "./to-update-weight-record-write";
import type { weightRecordWriteSchemas } from "./weight-record-write-schemas";

export const weightRecordHttpKind: HttpRecordKind<
  WeightRecord,
  z.infer<(typeof weightRecordWriteSchemas)[number]>
> = {
  name: "weight_record",
  writeTypes: ["create_weight_record", "update_weight_record", "source_deleted_weight_record"],
  toWrite: (write) =>
    match(write)
      .with({ type: "create_weight_record" }, toCreateWeightRecordWrite)
      .with({ type: "update_weight_record" }, toUpdateWeightRecordWrite)
      .with({ type: "source_deleted_weight_record" }, toSourceDeletedWeightRecordWrite)
      .exhaustive(),
  toChangeResponse: (sequence, current, recordId) =>
    match(current)
      .with({ status: "value" }, ({ value }) => toWeightRecordChangeResponse(sequence, value))
      .with({ status: "deleted" }, () => toWeightRecordDeletionChangeResponse(sequence, recordId))
      .exhaustive(),
};
