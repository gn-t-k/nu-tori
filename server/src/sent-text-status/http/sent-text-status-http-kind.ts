import { z } from "@hono/zod-openapi";
import { match } from "ts-pattern";
import type { HttpRecordKind } from "../../http/sync-routes/http-record-kind";
import type { SentTextStatus } from "../domain/sent-text-status";

// 取りに行く変更の record の形。応答の SyncChange は種類によらず record を任意のオブジェクトで持つので、応答のスキーマからは指さない。
// 値は足すだけにするので、端末は知らない値を読み飛ばす
const sentTextStatusRecordSchema = z
  .object({
    sentTextId: z.string(),
    classification: z.string().openapi({
      description: "読み分けの今の結果。pending（読み分けを待っている）・meal・conversation",
      example: "pending",
    }),
    replyStatus: z.string().openapi({
      description:
        "応答の状態。none（返事の依頼が無い）・awaiting（応答待ち）・replied（返事あり）・halted（その日の回数切れ）・failed（作れなかった）",
      example: "awaiting",
    }),
    replyFailureReason: z.string().optional().openapi({
      description:
        "replyStatus が failed のときだけある、作れなかった理由。retries_exhausted（やり直しを使い切った）・bad_request（提供元の 400）",
      example: "retries_exhausted",
    }),
  })
  .openapi({
    description: "kind が sent_text_status の変更の record。recordId は送った文章の ID",
  });

export const sentTextStatusHttpKind: HttpRecordKind<
  SentTextStatus,
  never,
  typeof sentTextStatusRecordSchema
> = {
  // サーバーだけが書く種類なので、端末からの書き込みは届かない
  writes: undefined,
  recordSchema: sentTextStatusRecordSchema,
  toRecord: (value, sentTextId) => ({
    sentTextId,
    classification: value.classification,
    ...match(value.reply)
      .returnType<{ replyStatus: string; replyFailureReason?: string }>()
      .with({ type: "failed" }, ({ type, reason }) => ({
        replyStatus: type,
        replyFailureReason: reason,
      }))
      .with(
        { type: "none" },
        { type: "awaiting" },
        { type: "replied" },
        { type: "halted" },
        ({ type }) => ({
          replyStatus: type,
        }),
      )
      .exhaustive(),
  }),
};
