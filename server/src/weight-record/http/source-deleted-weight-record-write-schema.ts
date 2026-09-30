import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";

export const sourceDeletedWeightRecordWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("source_deleted_weight_record"),
    weightRecordId: z.string().min(1),
  })
  .openapi("SourceDeletedWeightRecordWrite");
