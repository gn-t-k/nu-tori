import { and, asc, count, eq, isNull } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { RecordId } from "../../domain/record-id";
import { match } from "ts-pattern";
import { aiUtteranceTables } from "../../ai-utterance/durable-object/ai-utterance-tables";
import { sentTextTables } from "../../sent-text/durable-object/sent-text-tables";
import type { ReplyAttempt, ReplyAttemptConclusion } from "../domain/reply-attempt";
import type { ReplyStore } from "../domain/reply-store";
import { replyTables } from "./reply-tables";

const { sentTexts, sentTextClassifications } = sentTextTables;
const {
  replyRequests,
  classificationReplyRequests,
  replyRequestHalts,
  replyGenerations,
  replyGenerationAttempts,
  replyGenerationAttemptResults,
  replyGenerationAttemptErrors,
  replyGenerationAbandonments,
} = replyTables;
const { aiUtterances } = aiUtteranceTables;

const sentTextColumns = {
  id: sentTexts.id,
  body: sentTexts.body,
  sentAt: sentTexts.sentAt,
  timeZone: sentTexts.sentTimeZone,
};

// 依頼の時刻は、きっかけの時刻（読み分けなら読み分けた時刻）。
// きっかけ（会話として送り直した・送り直した）を足すときは、その控えの要求の時刻を足し、ここで1つにまとめる
const requestedAt = sentTextClassifications.classifiedAt;

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
          requestedAt,
        })
        .from(replyRequests)
        .innerJoin(sentTexts, eq(sentTexts.id, replyRequests.sentTextId))
        .innerJoin(
          classificationReplyRequests,
          eq(classificationReplyRequests.replyRequestId, replyRequests.id),
        )
        .innerJoin(
          sentTextClassifications,
          eq(sentTextClassifications.sentTextId, replyRequests.sentTextId),
        )
        .leftJoin(replyRequestHalts, eq(replyRequestHalts.replyRequestId, replyRequests.id))
        .leftJoin(replyGenerations, eq(replyGenerations.replyRequestId, replyRequests.id))
        .where(and(isNull(replyRequestHalts.replyRequestId), isNull(replyGenerations.id)))
        .orderBy(asc(sentTexts.sentAt), asc(sentTexts.id))
        .all(),
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
        .select({ generationId: replyGenerations.id, sentText: sentTextColumns, requestedAt })
        .from(replyGenerations)
        .innerJoin(replyRequests, eq(replyRequests.id, replyGenerations.replyRequestId))
        .innerJoin(sentTexts, eq(sentTexts.id, replyRequests.sentTextId))
        .innerJoin(
          classificationReplyRequests,
          eq(classificationReplyRequests.replyRequestId, replyRequests.id),
        )
        .innerJoin(
          sentTextClassifications,
          eq(sentTextClassifications.sentTextId, replyRequests.sentTextId),
        )
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
        .map((generation) => ({ ...generation, attempts: findAttempts(generation.generationId) })),
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
