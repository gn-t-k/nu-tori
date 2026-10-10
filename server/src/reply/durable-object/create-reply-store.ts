import { and, asc, count, eq, isNull } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { match } from "ts-pattern";
import { aiUtteranceTables } from "../../ai-utterance/durable-object/ai-utterance-tables";
import type { RecordId } from "../../domain/record-id";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { sentTextTables } from "../../sent-text/durable-object/sent-text-tables";
import type { ReplyAttempt, ReplyAttemptConclusion } from "../domain/reply-attempt";
import type { ReplyStore } from "../domain/reply-store";
import { replyTables } from "./reply-tables";

const { sentTexts, sentTextClassifications } = sentTextTables;
const {
  replyRequests,
  conversationResendReplyRequests,
  replyRequestHalts,
  replyGenerations,
  replyGenerationAttempts,
  replyGenerationAttemptResults,
  replyGenerationAttemptErrors,
  replyGenerationAbandonments,
} = replyTables;
const { aiUtterances } = aiUtteranceTables;
const { syncWriteReceipts, syncRequestLogs } = syncLedgerTables;

const sentTextColumns = {
  id: sentTexts.id,
  body: sentTexts.body,
  sentAt: sentTexts.sentAt,
  timeZone: sentTexts.sentTimeZone,
};

// 依頼の時刻を出すための列。きっかけの時刻で、読み分けなら読み分けた時刻、会話として送り直したなら、その書き込みを受け取った時刻。
// 会話として送り直した文章にも食事と読み分けた行があるので、控えの時刻を先に採る。送り直した（#430）を足すときは、その控えの時刻もここに足す
const requestTimes = {
  classifiedAt: sentTextClassifications.classifiedAt,
  conversationResentAt: syncRequestLogs.receivedAt,
};

const toRequestedAt = (times: {
  classifiedAt: Date | null;
  conversationResentAt: Date | null;
}): Date => {
  const requestedAt = times.conversationResentAt ?? times.classifiedAt;
  if (requestedAt === null) {
    throw new Error("返事の依頼に、きっかけの時刻が無い");
  }
  return requestedAt;
};

export const createReplyStore = (db: DrizzleSqliteDODatabase): ReplyStore => {
  const findAttempts = (generationId: RecordId): ReplyAttempt[] =>
    db
      .select({
        attemptedAt: replyGenerationAttempts.attemptedAt,
        endedAt: replyGenerationAttemptResults.endedAt,
        result: replyGenerationAttemptResults.result,
        errorType: replyGenerationAttemptErrors.errorType,
      })
      .from(replyGenerationAttempts)
      .leftJoin(
        replyGenerationAttemptResults,
        eq(replyGenerationAttemptResults.replyGenerationAttemptId, replyGenerationAttempts.id),
      )
      .leftJoin(
        replyGenerationAttemptErrors,
        eq(replyGenerationAttemptErrors.replyGenerationAttemptId, replyGenerationAttempts.id),
      )
      .where(eq(replyGenerationAttempts.replyGenerationId, generationId))
      .orderBy(asc(replyGenerationAttempts.attemptedAt), asc(replyGenerationAttempts.id))
      .all()
      .map(({ attemptedAt, endedAt, result, errorType }) => ({
        attemptedAt,
        ended:
          endedAt === null || result === null
            ? undefined
            : { endedAt, conclusion: toConclusion(result, errorType) },
      }));

  return {
    // 待っている依頼は「回数切れも生成も無いこと」で絞るので、索引が効かない（#419 の「索引」の置かないもの）
    findWaitingRequests: () =>
      db
        .select({
          requestId: replyRequests.id,
          countedOn: replyRequests.countedOn,
          sentText: sentTextColumns,
          ...requestTimes,
        })
        .from(replyRequests)
        .innerJoin(sentTexts, eq(sentTexts.id, replyRequests.sentTextId))
        .leftJoin(
          sentTextClassifications,
          eq(sentTextClassifications.sentTextId, replyRequests.sentTextId),
        )
        .leftJoin(
          conversationResendReplyRequests,
          eq(conversationResendReplyRequests.replyRequestId, replyRequests.id),
        )
        .leftJoin(
          syncWriteReceipts,
          eq(syncWriteReceipts.id, conversationResendReplyRequests.syncWriteReceiptId),
        )
        .leftJoin(syncRequestLogs, eq(syncRequestLogs.id, syncWriteReceipts.syncRequestLogId))
        .leftJoin(replyRequestHalts, eq(replyRequestHalts.replyRequestId, replyRequests.id))
        .leftJoin(replyGenerations, eq(replyGenerations.replyRequestId, replyRequests.id))
        .where(and(isNull(replyRequestHalts.replyRequestId), isNull(replyGenerations.id)))
        .orderBy(asc(sentTexts.sentAt), asc(sentTexts.id))
        .all()
        .map(({ requestId, countedOn, sentText, ...times }) => ({
          requestId,
          countedOn,
          sentText,
          requestedAt: toRequestedAt(times),
        })),
    countGenerationsCountedOn: (countedOn) =>
      db
        .select({ count: count() })
        .from(replyGenerations)
        .innerJoin(replyRequests, eq(replyRequests.id, replyGenerations.replyRequestId))
        .where(eq(replyRequests.countedOn, countedOn))
        .get()?.count ?? 0,
    // 続いている生成も「返事も作れなかったも無いこと」で絞るので、索引が効かない
    findContinuingGenerations: () =>
      db
        .select({ generationId: replyGenerations.id, sentText: sentTextColumns, ...requestTimes })
        .from(replyGenerations)
        .innerJoin(replyRequests, eq(replyRequests.id, replyGenerations.replyRequestId))
        .innerJoin(sentTexts, eq(sentTexts.id, replyRequests.sentTextId))
        .leftJoin(
          sentTextClassifications,
          eq(sentTextClassifications.sentTextId, replyRequests.sentTextId),
        )
        .leftJoin(
          conversationResendReplyRequests,
          eq(conversationResendReplyRequests.replyRequestId, replyRequests.id),
        )
        .leftJoin(
          syncWriteReceipts,
          eq(syncWriteReceipts.id, conversationResendReplyRequests.syncWriteReceiptId),
        )
        .leftJoin(syncRequestLogs, eq(syncRequestLogs.id, syncWriteReceipts.syncRequestLogId))
        .leftJoin(aiUtterances, eq(aiUtterances.replyGenerationId, replyGenerations.id))
        .leftJoin(
          replyGenerationAbandonments,
          eq(replyGenerationAbandonments.replyGenerationId, replyGenerations.id),
        )
        .where(
          and(
            isNull(aiUtterances.replyGenerationId),
            isNull(replyGenerationAbandonments.replyGenerationId),
          ),
        )
        .orderBy(asc(sentTexts.sentAt), asc(sentTexts.id))
        .all()
        .map(({ generationId, sentText, ...times }) => ({
          generationId,
          sentText,
          requestedAt: toRequestedAt(times),
          attempts: findAttempts(generationId),
        })),
    findContinuingGenerationId: (sentTextId) =>
      db
        .select({ id: replyGenerations.id })
        .from(replyGenerations)
        .innerJoin(replyRequests, eq(replyRequests.id, replyGenerations.replyRequestId))
        .leftJoin(aiUtterances, eq(aiUtterances.replyGenerationId, replyGenerations.id))
        .leftJoin(
          replyGenerationAbandonments,
          eq(replyGenerationAbandonments.replyGenerationId, replyGenerations.id),
        )
        .where(
          and(
            eq(replyRequests.sentTextId, sentTextId),
            isNull(aiUtterances.replyGenerationId),
            isNull(replyGenerationAbandonments.replyGenerationId),
          ),
        )
        .get()?.id,
    findAttempts,
    hasEnded: (generationId) =>
      db
        .select({ id: aiUtterances.replyGenerationId })
        .from(aiUtterances)
        .where(eq(aiUtterances.replyGenerationId, generationId))
        .get() !== undefined ||
      db
        .select({ id: replyGenerationAbandonments.replyGenerationId })
        .from(replyGenerationAbandonments)
        .where(eq(replyGenerationAbandonments.replyGenerationId, generationId))
        .get() !== undefined,
    hasRequest: (sentTextId) =>
      db
        .select({ id: replyRequests.id })
        .from(replyRequests)
        .where(eq(replyRequests.sentTextId, sentTextId))
        .get() !== undefined,
  };
};

const toConclusion = (
  result: (typeof replyGenerationAttemptResults.$inferSelect)["result"],
  errorType: string | null,
): ReplyAttemptConclusion =>
  match(result)
    .returnType<ReplyAttemptConclusion>()
    .with("succeeded", "timed_out", "invalid_response", (other) => ({ result: other }))
    .with("provider_error", "bad_request", (failed) => {
      if (errorType === null) {
        throw new Error("提供元のエラーと 400 の結果に、エラーの種類が無い");
      }
      return { result: failed, errorType };
    })
    .exhaustive();
