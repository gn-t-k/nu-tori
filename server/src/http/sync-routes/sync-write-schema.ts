import { z } from "@hono/zod-openapi";
import { updateAccountSettingsWriteSchema } from "../../account-settings/http/account-settings-write-schema";
import {
  createWeightRecordWriteSchema,
  sourceDeletedWeightRecordWriteSchema,
  updateWeightRecordWriteSchema,
} from "../../weight-record/http/weight-record-write-schema";
import { registeredWriteSchemas } from "./registered-write-schemas";

// 登録簿の種類の分と、今の道の分を合わせて導く
const legacyWriteSchemas = [
  createWeightRecordWriteSchema,
  updateWeightRecordWriteSchema,
  sourceDeletedWeightRecordWriteSchema,
  updateAccountSettingsWriteSchema,
] as const;

export const syncWriteSchema = z
  .discriminatedUnion("type", [...legacyWriteSchemas, ...registeredWriteSchemas])
  .openapi("SyncWrite", {
    description: "アカウントの設定は、記録が無くても直す書き込みで送り、サーバーが無ければ作る",
  });
