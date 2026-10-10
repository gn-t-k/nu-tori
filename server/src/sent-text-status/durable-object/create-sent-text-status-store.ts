import { desc, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { RecordId } from "../../domain/record-id";
import { aiUtteranceTables } from "../../ai-utterance/durable-object/ai-utterance-tables";
import { replyTables } from "../../reply/durable-object/reply-tables";
import { sentTextTables } from "../../sent-text/durable-object/sent-text-tables";
import type { ReplyFailureReason } from "../domain/sent-text-status";
import type { ReplyRequestProgress, SentTextStatusStore } from "../domain/sent-text-status-store";

const { sentTextClassifications } = sentTextTables;
const {
  replyRequests,
  replyRequestHalts,
  replyGenerations,
  replyGenerationAttempts,
  replyGenerationAttemptResults,
  replyGenerationAbandonments,
} = replyTables;
const { aiUtterances } = aiUtteranceTables;

export const createSentTextStatusStore = (db: DrizzleSqliteDODatabase): SentTextStatusStore => ({
  findClassification: (sentTextId) =>
    db
      .select({ result: sentTextClassifications.result })
      .from(sentTextClassifications)
      .where(eq(sentTextClassifications.sentTextId, sentTextId))
      .get()?.result,
  findReplyRequestProgresses: (sentTextId) =>
    db
      .select({
        haltedAt: replyRequestHalts.haltedAt,
        generationId: replyGenerations.id,
        utteranceId: aiUtterances.replyGenerationId,
        abandonedAt: replyGenerationAbandonments.abandonedAt,
      })
      .from(replyRequests)
      .leftJoin(replyRequestHalts, eq(replyRequestHalts.replyRequestId, replyRequests.id))
      .leftJoin(replyGenerations, eq(replyGenerations.replyRequestId, replyRequests.id))
      .leftJoin(aiUtterances, eq(aiUtterances.replyGenerationId, replyGenerations.id))
      .leftJoin(
        replyGenerationAbandonments,
        eq(replyGenerationAbandonments.replyGenerationId, replyGenerations.id),
      )
      .where(eq(replyRequests.sentTextId, sentTextId))
      .all()
      .map(({ haltedAt, generationId, utteranceId, abandonedAt }): ReplyRequestProgress => {
        if (haltedAt !== null) {
          return { progress: "halted", endedAt: haltedAt };
        }
        if (generationId === null) {
          return { progress: "waiting" };
        }
        if (utteranceId !== null) {
          return { progress: "replied" };
        }
        if (abandonedAt !== null) {
          return {
            progress: "abandoned",
            endedAt: abandonedAt,
            reason: findFailureReason(db, generationId),
          };
        }
        return { progress: "generating" };
      }),
});

// 最後の試みの結果が 400 なら bad_request、ほか（結果の無い試みを含む）はやり直しを使い切った
const findFailureReason = (
  db: DrizzleSqliteDODatabase,
  generationId: RecordId,
): ReplyFailureReason =>
  db
    .select({ result: replyGenerationAttemptResults.result })
    .from(replyGenerationAttempts)
    .leftJoin(
      replyGenerationAttemptResults,
      eq(replyGenerationAttemptResults.replyGenerationAttemptId, replyGenerationAttempts.id),
    )
    .where(eq(replyGenerationAttempts.replyGenerationId, generationId))
    .orderBy(desc(replyGenerationAttempts.attemptedAt), desc(replyGenerationAttempts.id))
    .limit(1)
    .get()?.result === "bad_request"
    ? "bad_request"
    : "retries_exhausted";
