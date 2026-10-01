import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";

const updateAccountSettingsWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("update_account_settings"),
    accountSettings: z.object({
      id: z.string().min(1).openapi({
        description:
          "端末で振ったアカウントの設定の ID。アカウント ID から名前空間を分けた UUID v5 で出す。サーバーは ID では探さず、アカウントに1件の記録として持つ",
      }),
      sendsUsageData: z.boolean(),
    }),
  })
  .openapi("UpdateAccountSettingsWrite");

// アカウントの設定の書き込みのスキーマ。型を保つため as const で並べる
export const accountSettingsWriteSchemas = [updateAccountSettingsWriteSchema] as const;
