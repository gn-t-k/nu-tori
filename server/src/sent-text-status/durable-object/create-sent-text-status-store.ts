import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { sentTextTables } from "../../sent-text/durable-object/sent-text-tables";
import type { SentTextStatusStore } from "../domain/sent-text-status-store";

const { sentTextClassifications } = sentTextTables;

export const createSentTextStatusStore = (db: DrizzleSqliteDODatabase): SentTextStatusStore => ({
  findClassification: (sentTextId) =>
    db
      .select({ result: sentTextClassifications.result })
      .from(sentTextClassifications)
      .where(eq(sentTextClassifications.sentTextId, sentTextId))
      .get()?.result,
});
