import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";
import { weightRecordFields } from "./weight-record-fields";

export const updateWeightRecordWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("update_weight_record"),
    weightRecord: z.object({
      ...weightRecordFields,
      version: z.number().int(),
    }),
  })
  .openapi("UpdateWeightRecordWrite");
