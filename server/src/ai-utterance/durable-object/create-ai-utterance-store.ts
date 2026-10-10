import { asc, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { replyTables } from "../../reply/durable-object/reply-tables";
import type { AiUtteranceStore } from "../domain/ai-utterance-store";
import { aiUtteranceTables } from "./ai-utterance-tables";

const { aiUtterances, aiUtteranceMeals } = aiUtteranceTables;
const { replyGenerations, replyRequests } = replyTables;

export const createAiUtteranceStore = (db: DrizzleSqliteDODatabase): AiUtteranceStore => ({
  find: (id) => {
    const row = db
      .select({ body: aiUtterances.body, sentTextId: replyRequests.sentTextId })
      .from(aiUtterances)
      .innerJoin(replyGenerations, eq(replyGenerations.id, aiUtterances.replyGenerationId))
      .innerJoin(replyRequests, eq(replyRequests.id, replyGenerations.replyRequestId))
      .where(eq(aiUtterances.replyGenerationId, id))
      .get();
    if (row === undefined) {
      return undefined;
    }
    const meals = db
      .select({ mealId: aiUtteranceMeals.mealId })
      .from(aiUtteranceMeals)
      .where(eq(aiUtteranceMeals.aiUtteranceId, id))
      .orderBy(asc(aiUtteranceMeals.positionInUtterance))
      .all();
    return {
      id,
      body: row.body,
      sentTextId: row.sentTextId,
      mealIds: meals.map(({ mealId }) => mealId),
    };
  },
});
