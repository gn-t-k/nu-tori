import type { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import { toUpdateAccountSettingsWrite } from "../../account-settings/http/to-account-settings-write";
import type { SyncWrite } from "../../domain/sync-write";
import {
  toCreateWeightRecordWrite,
  toSourceDeletedWeightRecordWrite,
  toUpdateWeightRecordWrite,
} from "../../weight-record/http/to-weight-record-write";
import type { syncWriteSchema } from "./sync-write-schema";

export const toSyncWrite = (write: z.infer<typeof syncWriteSchema>): SyncWrite =>
  match(write)
    .with({ type: "create_weight_record" }, toCreateWeightRecordWrite)
    .with({ type: "update_weight_record" }, toUpdateWeightRecordWrite)
    .with({ type: "source_deleted_weight_record" }, toSourceDeletedWeightRecordWrite)
    .with({ type: "update_account_settings" }, toUpdateAccountSettingsWrite)
    .exhaustive();
