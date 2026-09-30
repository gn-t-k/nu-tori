import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";
import { weightRecordFields } from "./weight-record-fields";

export const createWeightRecordWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("create_weight_record"),
    weightRecord: z.object({
      ...weightRecordFields,
      imported: z
        .object({
          sourceAppName: z.string(),
          sourceBundleId: z.string(),
          healthkitSampleUuid: z.string().min(1),
          bodyFat: z
            .object({
              percentage: z.number(),
              healthkitSampleUuid: z.string().min(1),
            })
            .optional(),
        })
        .optional(),
    }),
  })
  .openapi("CreateWeightRecordWrite");
