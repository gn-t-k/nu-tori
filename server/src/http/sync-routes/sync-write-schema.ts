import { z } from "@hono/zod-openapi";
import { updateAccountSettingsWriteSchema } from "../../account-settings/http/account-settings-write-schema";
import { registeredWriteSchemas } from "./registered-write-schemas";

// 登録簿の種類の分と、今の道の分を合わせて導く。書き出す openapi.json の並びを保つため、登録簿の分を先に置く
const legacyWriteSchemas = [updateAccountSettingsWriteSchema] as const;

export const syncWriteSchema = z
  .discriminatedUnion("type", [...registeredWriteSchemas, ...legacyWriteSchemas])
  .openapi("SyncWrite", {
    description: "アカウントの設定は、記録が無くても直す書き込みで送り、サーバーが無ければ作る",
  });
