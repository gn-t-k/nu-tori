import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
export const accountSettingsRecordSchema = z
  .object({ id: z.string(), sendsUsageData: z.boolean() })
  .openapi({
    description: "kind が account_settings の変更の record。アカウントに1つで、削除の印は無い",
  });
