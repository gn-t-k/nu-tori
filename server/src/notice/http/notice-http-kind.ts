import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import { recordIdSchema } from "../../domain/record-id";
import type { SyncWrite } from "../../domain/sync-write";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";
import type { Notice } from "../domain/notice";

// 取りに行く変更（SyncChange）の kind が notice のときの record の形。応答の record は種類によらず
// 文字列をキーにした値なので、openapi.json には部品として書き出し、端末が値の形を読めるようにする
const noticeRecordSchema = z.object({
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
});

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
      id: recordIdSchema,
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
    noticeId: recordIdSchema,
    response: z.object({
      respondedAt: timestampSchema,
      timeZone: timeZoneSchema,
    }),
  })
  .openapi("RespondNoticeWrite");

// 知らせの書き込みのスキーマ。型を保つため as const で並べる
const noticeWriteSchemas = [createNoticeWriteSchema, respondNoticeWriteSchema] as const;

export const noticeHttpKind: HttpRecordKind<
  Notice,
  (typeof noticeWriteSchemas)[number],
  typeof noticeRecordSchema
> = {
  writes: {
    schemas: noticeWriteSchemas,
    toWrite: (write) =>
      match(write)
        .with({ type: "create_notice" }, ({ id, notice }): SyncWrite => ({
          id,
          type: "create_notice",
          notice: {
            id: notice.id,
            noticeType: notice.noticeType,
            issuedAt: new Date(notice.issuedAt),
            timeZone: notice.timeZone,
            targetOn: notice.targetOn,
          },
        }))
        .with({ type: "respond_notice" }, ({ id, noticeId, response }): SyncWrite => ({
          id,
          type: "respond_notice",
          noticeId,
          response: { respondedAt: new Date(response.respondedAt), timeZone: response.timeZone },
        }))
        .exhaustive(),
  },
  recordSchema: noticeRecordSchema,
  toRecord: (value) => ({
    id: value.id,
    noticeType: value.noticeType,
    issuedAt: value.issuedAt.getTime(),
    timeZone: value.timeZone,
    targetOn: value.targetOn,
    response:
      value.response === undefined
        ? undefined
        : { respondedAt: value.response.respondedAt.getTime(), timeZone: value.response.timeZone },
  }),
};
