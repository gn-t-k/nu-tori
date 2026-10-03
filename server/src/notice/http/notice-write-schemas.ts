import { z } from "@hono/zod-openapi";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";

// Date が表せる範囲。これを超える時刻は、日付の計算で例外になる
const maximumTimestamp = 8.64e15;

const timestampSchema = z
  .number()
  .int()
  .min(-maximumTimestamp)
  .max(maximumTimestamp)
  .openapi({ description: "UNIX 時刻のミリ秒（UTC）" });

const timeZoneSchema = z.string().openapi({ example: "Asia/Tokyo" });

const createNoticeWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("create_notice"),
    notice: z.object({
      id: z.string().min(1),
      noticeType: z.string().openapi({
        description: "missed_weight_record（体重の記録忘れ）。知らない値は受け付けない",
        example: "missed_weight_record",
      }),
      issuedAt: timestampSchema,
      timeZone: timeZoneSchema,
      targetOn: z.string().openapi({ description: "YYYY-MM-DD", example: "2026-01-01" }),
    }),
  })
  .openapi("CreateNoticeWrite");

const respondNoticeWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("respond_notice"),
    noticeId: z.string().min(1),
    response: z.object({
      respondedAt: timestampSchema,
      timeZone: timeZoneSchema,
    }),
  })
  .openapi("RespondNoticeWrite");

// 知らせの書き込みのスキーマ。型を保つため as const で並べる
export const noticeWriteSchemas = [createNoticeWriteSchema, respondNoticeWriteSchema] as const;
