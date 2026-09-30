import { z } from "@hono/zod-openapi";
import { updateAccountSettingsWriteSchema } from "../../account-settings/http/account-settings-write-schema";
import {
  createWeightRecordWriteSchema,
  sourceDeletedWeightRecordWriteSchema,
  updateWeightRecordWriteSchema,
} from "../../weight-record/http/weight-record-write-schema";

export const syncWriteSchema = z
  .discriminatedUnion("type", [
    createWeightRecordWriteSchema,
    updateWeightRecordWriteSchema,
    sourceDeletedWeightRecordWriteSchema,
    updateAccountSettingsWriteSchema,
  ])
  .openapi("SyncWrite", {
    description: "アカウントの設定は、記録が無くても直す書き込みで送り、サーバーが無ければ作る",
  });
