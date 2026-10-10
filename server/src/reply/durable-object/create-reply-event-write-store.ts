import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { match } from "ts-pattern";
import { aiUtteranceTables } from "../../ai-utterance/durable-object/ai-utterance-tables";
import type { ReplyEventWriteStore } from "../domain/reply-event-write-store";
import { replyTables } from "./reply-tables";

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
const { aiUtterances, aiUtteranceMeals } = aiUtteranceTables;

export const createReplyEventWriteStore = (db: DrizzleSqliteDODatabase): ReplyEventWriteStore => ({
  insertRequest: ({ id, sentTextId, countedOn, trigger }) => {
    db.insert(replyRequests).values({ id, sentTextId, countedOn }).run();
    match(trigger)
      .with({ type: "classification" }, () => {
        db.insert(classificationReplyRequests).values({ replyRequestId: id }).run();
      })
      .exhaustive();
  },
  insertHalt: ({ requestId, haltedAt }) => {
    db.insert(replyRequestHalts).values({ replyRequestId: requestId, haltedAt }).run();
  },
  insertGeneration: ({ id, requestId, startedAt }) => {
    db.insert(replyGenerations).values({ id, replyRequestId: requestId, startedAt }).run();
  },
  insertAttempt: ({ id, generationId, attemptedAt }) => {
    db.insert(replyGenerationAttempts)
      .values({ id, replyGenerationId: generationId, attemptedAt })
      .run();
  },
  insertAttemptResult: ({ attemptId, endedAt, conclusion }) => {
    db.insert(replyGenerationAttemptResults)
      .values({ replyGenerationAttemptId: attemptId, endedAt, result: conclusion.result })
      .run();
    match(conclusion)
      .with(
        { result: "succeeded" },
        { result: "timed_out" },
        { result: "invalid_response" },
        () => {
          // エラーの種類は、提供元のエラーと 400 のときだけ
        },
      )
      .with({ result: "provider_error" }, { result: "bad_request" }, ({ errorType }) => {
        db.insert(replyGenerationAttemptErrors)
          .values({ replyGenerationAttemptId: attemptId, errorType })
          .run();
      })
      .exhaustive();
  },
  insertUtterance: ({ generationId, body, mealIds }) => {
    db.insert(aiUtterances).values({ replyGenerationId: generationId, body }).run();
    mealIds.forEach((mealId, positionInUtterance) => {
      db.insert(aiUtteranceMeals)
        .values({ aiUtteranceId: generationId, mealId, positionInUtterance })
        .run();
    });
  },
  insertAbandonment: ({ generationId, abandonedAt }) => {
    db.insert(replyGenerationAbandonments)
      .values({ replyGenerationId: generationId, abandonedAt })
      .run();
  },
  findSentTextIdOfRequest: (requestId) =>
    db
      .select({ sentTextId: replyRequests.sentTextId })
      .from(replyRequests)
      .where(eq(replyRequests.id, requestId))
      .get()?.sentTextId,
  findSentTextIdOfGeneration: (generationId) =>
    db
      .select({ sentTextId: replyRequests.sentTextId })
      .from(replyGenerations)
      .innerJoin(replyRequests, eq(replyRequests.id, replyGenerations.replyRequestId))
      .where(eq(replyGenerations.id, generationId))
      .get()?.sentTextId,
  hasGeneration: (requestId) =>
    db
      .select({ id: replyGenerations.id })
      .from(replyGenerations)
      .where(eq(replyGenerations.replyRequestId, requestId))
      .get() !== undefined,
  hasHalt: (requestId) =>
    db
      .select({ id: replyRequestHalts.replyRequestId })
      .from(replyRequestHalts)
      .where(eq(replyRequestHalts.replyRequestId, requestId))
      .get() !== undefined,
  hasUtterance: (generationId) =>
    db
      .select({ id: aiUtterances.replyGenerationId })
      .from(aiUtterances)
      .where(eq(aiUtterances.replyGenerationId, generationId))
      .get() !== undefined,
  hasAbandonment: (generationId) =>
    db
      .select({ id: replyGenerationAbandonments.replyGenerationId })
      .from(replyGenerationAbandonments)
      .where(eq(replyGenerationAbandonments.replyGenerationId, generationId))
      .get() !== undefined,
});
