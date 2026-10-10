import { z } from "@hono/zod-openapi";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない。
// 値は足すだけにするので、端末は知らない値を読み飛ばす
export const sentTextStatusRecordSchema = z
  .object({
    sentTextId: z.string(),
    classification: z.string().openapi({
      description: "読み分けの今の結果。pending（読み分けを待っている）・meal・conversation",
      example: "pending",
    }),
  })
  .openapi({
    description: "kind が sent_text_status の変更の record。recordId は送った文章の ID",
  });
