import { z } from "@hono/zod-openapi";

// 取りに行く変更（SyncChange）の kind が notice のときの record の形。応答の record は種類によらず
// 文字列をキーにした値なので、openapi.json には部品として書き出し、端末が値の形を読めるようにする
export const noticeRecordSchema = z
  .object({
    id: z.string(),
    noticeType: z.string().openapi({ example: "missed_weight_record" }),
    issuedAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    timeZone: z.string().openapi({ example: "Asia/Tokyo" }),
    targetOn: z.string().openapi({ description: "YYYY-MM-DD" }),
    response: z
      .object({
        respondedAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
        timeZone: z.string().openapi({ example: "Asia/Tokyo" }),
      })
      .optional()
      .openapi({ description: "答えていれば付く" }),
  })
  .openapi("NoticeRecord");
