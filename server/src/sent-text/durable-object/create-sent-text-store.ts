import { and, asc, count, eq, gt, gte, isNull } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import type { SentTextStore } from "../domain/sent-text-store";
import { sentTextTables } from "./sent-text-tables";

const {
  sentTexts,
  sentTextClassifications,
  sentTextClassificationCalls,
  sentTextMeals,
  sentTextConversationResends,
  sentTextResends,
  conversationResendMealDeletions,
} = sentTextTables;
const { syncWriteReceipts, syncRequestLogs } = syncLedgerTables;

const sentTextColumns = {
  id: sentTexts.id,
  body: sentTexts.body,
  sentAt: sentTexts.sentAt,
  timeZone: sentTexts.sentTimeZone,
};

export const createSentTextStore = (db: DrizzleSqliteDODatabase): SentTextStore => ({
  find: (id) => db.select(sentTextColumns).from(sentTexts).where(eq(sentTexts.id, id)).get(),
  insert: ({ id, body, sentAt, timeZone }) => {
    db.insert(sentTexts).values({ id, body, sentAt, sentTimeZone: timeZone }).run();
  },
  findSentSince: (from) =>
    db
      .select(sentTextColumns)
      .from(sentTexts)
      .where(gte(sentTexts.sentAt, from))
      .orderBy(asc(sentTexts.sentAt), asc(sentTexts.id))
      .all(),
  // 読み分け待ちは「読み分けの行が無いこと」で絞るので、索引が効かない（#419 の「索引」の置かないもの）。
  // 受け取った時刻は、文章を作った（当てた）控えの要求の時刻
  findUnclassified: () =>
    db
      .select({ sentText: sentTextColumns, receivedAt: syncRequestLogs.receivedAt })
      .from(sentTexts)
      .leftJoin(sentTextClassifications, eq(sentTextClassifications.sentTextId, sentTexts.id))
      .innerJoin(
        syncWriteReceipts,
        and(
          eq(syncWriteReceipts.recordType, "sent_text"),
          eq(syncWriteReceipts.recordId, sentTexts.id),
          eq(syncWriteReceipts.kind, "create"),
          eq(syncWriteReceipts.result, "applied"),
        ),
      )
      .innerJoin(syncRequestLogs, eq(syncRequestLogs.id, syncWriteReceipts.syncRequestLogId))
      .where(isNull(sentTextClassifications.sentTextId))
      .orderBy(asc(sentTexts.sentAt), asc(sentTexts.id))
      .all(),
  insertClassification: ({ sentTextId, classifiedAt, result }) => {
    db.insert(sentTextClassifications).values({ sentTextId, classifiedAt, result }).run();
  },
  insertClassificationCall: ({ id, sentTextId, calledAt }) => {
    db.insert(sentTextClassificationCalls).values({ id, sentTextId, calledAt }).run();
  },
  countClassificationCallsAfter: (after) =>
    db
      .select({ count: count() })
      .from(sentTextClassificationCalls)
      .where(gt(sentTextClassificationCalls.calledAt, after))
      .get()?.count ?? 0,
  findMealIds: (sentTextId) =>
    db
      .select({ mealId: sentTextMeals.mealId })
      .from(sentTextMeals)
      .where(eq(sentTextMeals.sentTextId, sentTextId))
      .all()
      .map(({ mealId }) => mealId),
  insertConversationResend: (receiptId) => {
    db.insert(sentTextConversationResends).values({ syncWriteReceiptId: receiptId.value }).run();
  },
  insertConversationResendMealDeletion: (receiptId, mealId) => {
    db.insert(conversationResendMealDeletions)
      .values({ mealId, syncWriteReceiptId: receiptId.value })
      .run();
  },
  insertResend: (receiptId) => {
    db.insert(sentTextResends).values({ syncWriteReceiptId: receiptId.value }).run();
  },
});
