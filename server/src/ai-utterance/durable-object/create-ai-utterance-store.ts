import { asc, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { replyTables } from "../../reply/durable-object/reply-tables";
import type { AiUtterance } from "../domain/ai-utterance";
import type { AiUtteranceStore } from "../domain/ai-utterance-store";
import { aiUtteranceTables } from "./ai-utterance-tables";

const { aiUtterances, aiUtteranceMeals } = aiUtteranceTables;
const { replyGenerations, replyRequests } = replyTables;

export const createAiUtteranceStore = (db: DrizzleSqliteDODatabase): AiUtteranceStore => {
  const utterances = () =>
    db
      .select({
        id: aiUtterances.replyGenerationId,
        body: aiUtterances.body,
        sentTextId: replyRequests.sentTextId,
      })
      .from(aiUtterances)
      .innerJoin(replyGenerations, eq(replyGenerations.id, aiUtterances.replyGenerationId))
      .innerJoin(replyRequests, eq(replyRequests.id, replyGenerations.replyRequestId));
  const withMeals = (row: Omit<AiUtterance, "mealIds"> | undefined): AiUtterance | undefined => {
    if (row === undefined) {
      return undefined;
    }
    const meals = db
      .select({ mealId: aiUtteranceMeals.mealId })
      .from(aiUtteranceMeals)
      .where(eq(aiUtteranceMeals.aiUtteranceId, row.id))
      .orderBy(asc(aiUtteranceMeals.positionInUtterance))
      .all();
    return { ...row, mealIds: meals.map(({ mealId }) => mealId) };
  };
  return {
    find: (id) => withMeals(utterances().where(eq(aiUtterances.replyGenerationId, id)).get()),
    findOfSentText: (sentTextId) =>
      withMeals(utterances().where(eq(replyRequests.sentTextId, sentTextId)).get()),
  };
};
