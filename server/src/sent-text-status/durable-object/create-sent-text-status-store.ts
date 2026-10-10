import { and, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { sentTextTables } from "../../sent-text/durable-object/sent-text-tables";
import type { SentTextStatusStore } from "../domain/sent-text-status-store";

const { sentTextClassifications, sentTextConversationResends } = sentTextTables;
const { syncWriteReceipts } = syncLedgerTables;

export const createSentTextStatusStore = (db: DrizzleSqliteDODatabase): SentTextStatusStore => ({
  // 読み分けの行は書き換えないので、会話として送り直していれば、読み分けの結果によらず会話にする
  findClassification: (sentTextId) => {
    const resentAsConversation =
      db
        .select({ id: sentTextConversationResends.syncWriteReceiptId })
        .from(sentTextConversationResends)
        .innerJoin(
          syncWriteReceipts,
          eq(syncWriteReceipts.id, sentTextConversationResends.syncWriteReceiptId),
        )
        .where(
          and(
            eq(syncWriteReceipts.recordType, "sent_text"),
            eq(syncWriteReceipts.recordId, sentTextId),
          ),
        )
        .get() !== undefined;
    if (resentAsConversation) {
      return "conversation";
    }
    return db
      .select({ result: sentTextClassifications.result })
      .from(sentTextClassifications)
      .where(eq(sentTextClassifications.sentTextId, sentTextId))
      .get()?.result;
  },
});
