import { index, integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { sentTextTables } from "../../sent-text/durable-object/sent-text-tables";

// 返事の依頼。数える日は、依頼を作った時点のユーザーの最新のタイムゾーンでの日
const replyRequests = sqliteTable(
  "reply_requests",
  {
    id: text("id").primaryKey(),
    sentTextId: text("sent_text_id")
      .$type<RecordId>()
      .notNull()
      .references(() => sentTextTables.sentTexts.id),
    countedOn: text("counted_on").notNull(),
  },
  (table) => [
    index("reply_requests_sent_text_id").on(table.sentTextId),
    index("reply_requests_counted_on").on(table.countedOn),
  ],
);

// 依頼のきっかけ: 会話と読み分けた
const classificationReplyRequests = sqliteTable("classification_reply_requests", {
  replyRequestId: text("reply_request_id")
    .primaryKey()
    .references(() => replyRequests.id),
});

// 依頼のきっかけ: 送り直した
const resendReplyRequests = sqliteTable("resend_reply_requests", {
  replyRequestId: text("reply_request_id")
    .primaryKey()
    .references(() => replyRequests.id),
  syncWriteReceiptId: text("sync_write_receipt_id")
    .notNull()
    .unique()
    .references(() => sentTextTables.sentTextResends.syncWriteReceiptId),
});

// 依頼のきっかけ: 会話として送り直した
const conversationResendReplyRequests = sqliteTable("conversation_resend_reply_requests", {
  replyRequestId: text("reply_request_id")
    .primaryKey()
    .references(() => replyRequests.id),
  syncWriteReceiptId: text("sync_write_receipt_id")
    .notNull()
    .unique()
    .references(() => sentTextTables.sentTextConversationResends.syncWriteReceiptId),
});

// 回数切れ（提供元を呼ぶ前に依頼を止めた）
const replyRequestHalts = sqliteTable("reply_request_halts", {
  replyRequestId: text("reply_request_id")
    .primaryKey()
    .references(() => replyRequests.id),
  haltedAt: integer("halted_at", { mode: "timestamp_ms" }).notNull(),
});

// 返事の生成。1日の回数はこれを数える。ID は返事（ai_utterances）の ID を兼ねる
const replyGenerations = sqliteTable("reply_generations", {
  id: text("id").$type<RecordId>().primaryKey(),
  replyRequestId: text("reply_request_id")
    .notNull()
    .unique()
    .references(() => replyRequests.id),
  startedAt: integer("started_at", { mode: "timestamp_ms" }).notNull(),
});

const replyGenerationAttempts = sqliteTable(
  "reply_generation_attempts",
  {
    id: text("id").primaryKey(),
    replyGenerationId: text("reply_generation_id")
      .$type<RecordId>()
      .notNull()
      .references(() => replyGenerations.id),
    attemptedAt: integer("attempted_at", { mode: "timestamp_ms" }).notNull(),
  },
  (table) => [
    index("reply_generation_attempts_reply_generation_id").on(
      table.replyGenerationId,
      table.attemptedAt,
    ),
  ],
);

const replyGenerationAttemptResults = sqliteTable("reply_generation_attempt_results", {
  replyGenerationAttemptId: text("reply_generation_attempt_id")
    .primaryKey()
    .references(() => replyGenerationAttempts.id),
  endedAt: integer("ended_at", { mode: "timestamp_ms" }).notNull(),
  result: text("result", {
    enum: ["succeeded", "provider_error", "timed_out", "bad_request", "invalid_response"],
  }).notNull(),
});

// 提供元が返したエラーの種類。提供元の文字列なので enum にしない
const replyGenerationAttemptErrors = sqliteTable("reply_generation_attempt_errors", {
  replyGenerationAttemptId: text("reply_generation_attempt_id")
    .primaryKey()
    .references(() => replyGenerationAttemptResults.replyGenerationAttemptId),
  errorType: text("error_type").notNull(),
});

// 作れなかった。理由は列に持たず、最後の試みの結果が bad_request なら 400、ほかはやり直しを使い切った
const replyGenerationAbandonments = sqliteTable("reply_generation_abandonments", {
  replyGenerationId: text("reply_generation_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => replyGenerations.id),
  abandonedAt: integer("abandoned_at", { mode: "timestamp_ms" }).notNull(),
});

// 返事の流れの出来事の表（依頼・きっかけ・回数切れ・生成・試み・結果・作れなかった）。INSERT だけで持つ。
// 宣言は durable-object-migrations/ の SQL に合わせる
export const replyTables = {
  replyRequests,
  classificationReplyRequests,
  resendReplyRequests,
  conversationResendReplyRequests,
  replyRequestHalts,
  replyGenerations,
  replyGenerationAttempts,
  replyGenerationAttemptResults,
  replyGenerationAttemptErrors,
  replyGenerationAbandonments,
};
