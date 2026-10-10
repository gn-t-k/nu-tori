import { z } from "@hono/zod-openapi";
import { recordIdSchema } from "../../domain/record-id";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";

// Date が表せる範囲。これを超える時刻は、日付の計算で例外になる
const maximumTimestamp = 8.64e15;

const createSentTextWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("create_sent_text"),
    sentText: z.object({
      id: recordIdSchema,
      body: z.string().openapi({
        description:
          "本文。前後の空白を除いて 1〜500 のコードポイント（範囲はサーバーのドメイン層で確かめる）",
      }),
      sentAt: z
        .number()
        .int()
        .min(-maximumTimestamp)
        .max(maximumTimestamp)
        .openapi({ description: "送る操作をした時刻。UNIX 時刻のミリ秒（UTC）" }),
      timeZone: z
        .string()
        .openapi({ description: "送ったときのタイムゾーン（IANA 名）", example: "Asia/Tokyo" }),
    }),
  })
  .openapi("CreateSentTextWrite");

// 送った文章の書き込みのスキーマ。型を保つため as const で並べる
export const sentTextWriteSchemas = [createSentTextWriteSchema] as const;
