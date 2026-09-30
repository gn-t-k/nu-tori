import type { z } from "@hono/zod-openapi";
import type { SyncWrite } from "../../domain/sync-write";
import type { sourceDeletedWeightRecordWriteSchema } from "./source-deleted-weight-record-write-schema";

export const toSourceDeletedWeightRecordWrite = ({
  id,
  weightRecordId,
}: z.infer<typeof sourceDeletedWeightRecordWriteSchema>): SyncWrite => ({
  id,
  type: "source_deleted_weight_record",
  weightRecordId,
});
