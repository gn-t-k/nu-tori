import { z } from "@hono/zod-openapi";

// 受け付けなかった書き込みに添える、その記録のサーバーの今の値
// 値と削除の印の change は、取りに行く変更（SyncChange）と同じ形で、通し番号だけを持たない
export const syncWriteCurrentSchema = z
  .object({
    status: z.string().openapi({
      description:
        "value（値）、deleted（削除の印）、absent（記録も削除の印も無い）のどれか。値が増えても古い版のアプリが読めるよう文字列で持つ。知らない値は端末が何も当てない",
      example: "value",
    }),
    change: z
      .object({
        kind: z.string().openapi({ example: "weight_record" }),
        recordId: z.string(),
        record: z.record(z.string(), z.unknown()),
      })
      .optional()
      .openapi({ description: "status が value か deleted のときだけ付く" }),
  })
  .openapi("SyncWriteCurrent");
