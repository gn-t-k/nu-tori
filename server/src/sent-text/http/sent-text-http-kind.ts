import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import { recordIdSchema } from "../../domain/record-id";
import type { SyncWrite } from "../../domain/sync-write";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import { writeIdSchema } from "../../http/sync-routes/write-id-schema";
import type { SentText } from "../domain/sent-text";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない
const sentTextRecordSchema = z
  .object({
    id: z.string(),
    body: z.string(),
    sentAt: z.number().int().openapi({ description: "UNIX 時刻のミリ秒（UTC）" }),
    timeZone: z.string().openapi({ example: "Asia/Tokyo" }),
  })
  .openapi({
    description: "kind が sent_text の変更の record。送った文章は消えない",
  });

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

const resendSentTextAsConversationWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("resend_sent_text_as_conversation"),
    sentTextId: recordIdSchema.meta({
      description: "食事と読み分けた送った文章。その文章から作った食事を消し、会話にする",
    }),
  })
  .openapi("ResendSentTextAsConversationWrite");

const resendSentTextWriteSchema = z
  .object({
    id: writeIdSchema,
    type: z.literal("resend_sent_text"),
    sentTextId: recordIdSchema.meta({
      description: "返事を作れなかった・回数切れの送った文章。もう一度返事を作らせる",
    }),
  })
  .openapi("ResendSentTextWrite");

// 送った文章の書き込みのスキーマ。型を保つため as const で並べる
const sentTextWriteSchemas = [
  createSentTextWriteSchema,
  resendSentTextAsConversationWriteSchema,
  resendSentTextWriteSchema,
] as const;

export const sentTextHttpKind: HttpRecordKind<
  SentText,
  (typeof sentTextWriteSchemas)[number],
  typeof sentTextRecordSchema
> = {
  writes: {
    schemas: sentTextWriteSchemas,
    toWrite: (write) =>
      match(write)
        .with({ type: "create_sent_text" }, ({ id, sentText }): SyncWrite => ({
          id,
          type: "create_sent_text",
          sentText: {
            id: sentText.id,
            body: sentText.body,
            sentAt: new Date(sentText.sentAt),
            timeZone: sentText.timeZone,
          },
        }))
        .with({ type: "resend_sent_text_as_conversation" }, ({ id, sentTextId }): SyncWrite => ({
          id,
          type: "resend_sent_text_as_conversation",
          sentTextId,
        }))
        .with({ type: "resend_sent_text" }, ({ id, sentTextId }): SyncWrite => ({
          id,
          type: "resend_sent_text",
          sentTextId,
        }))
        .exhaustive(),
  },
  recordSchema: sentTextRecordSchema,
  toRecord: (value) => ({
    id: value.id,
    body: value.body,
    sentAt: value.sentAt.getTime(),
    timeZone: value.timeZone,
  }),
};
