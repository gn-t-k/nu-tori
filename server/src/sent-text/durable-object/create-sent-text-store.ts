import { eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { SentTextStore } from "../domain/sent-text-store";
import { sentTextTables } from "./sent-text-tables";

const { sentTexts } = sentTextTables;

export const createSentTextStore = (db: DrizzleSqliteDODatabase): SentTextStore => ({
  find: (id) =>
    db
      .select({
        id: sentTexts.id,
        body: sentTexts.body,
        sentAt: sentTexts.sentAt,
        timeZone: sentTexts.sentTimeZone,
      })
      .from(sentTexts)
      .where(eq(sentTexts.id, id))
      .get(),
  insert: ({ id, body, sentAt, timeZone }) => {
    db.insert(sentTexts).values({ id, body, sentAt, sentTimeZone: timeZone }).run();
  },
});
