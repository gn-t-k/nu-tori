import { index, integer, sqliteTable, text } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import { mealTables } from "../../meal/durable-object/meal-tables";

const sentTexts = sqliteTable(
  "sent_texts",
  {
    id: text("id").$type<RecordId>().primaryKey(),
    // 前後の空白を除いて 1〜500 字。ドメイン層で確かめる
    body: text("body").notNull(),
    sentAt: integer("sent_at", { mode: "timestamp_ms" }).notNull(),
    sentTimeZone: text("sent_time_zone").notNull(),
  },
  // 返事を作るときに、直近の発言を時刻の順に読むため
  (table) => [index("sent_texts_sent_at").on(table.sentAt)],
);

// 読み分けの今の結果。会話として送り直したら会話にする
const sentTextClassifications = sqliteTable("sent_text_classifications", {
  sentTextId: text("sent_text_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => sentTexts.id),
  classifiedAt: integer("classified_at", { mode: "timestamp_ms" }).notNull(),
  result: text("result", { enum: ["meal", "conversation"] }).notNull(),
});

// 会話として送り直す書き込みを当てたこと。文章は控えの record_id
const sentTextConversationResends = sqliteTable("sent_text_conversation_resends", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 送り直す書き込みを当てたこと。文章は控えの record_id
const sentTextResends = sqliteTable("sent_text_resends", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 会話として送り直して消した食事の削除の印。食事は消えるので、外部キーで指さず値で名指しする
const conversationResendMealDeletions = sqliteTable("conversation_resend_meal_deletions", {
  mealId: text("meal_id").$type<RecordId>().primaryKey(),
  syncWriteReceiptId: text("sync_write_receipt_id")
    .notNull()
    .references(() => sentTextConversationResends.syncWriteReceiptId),
});

// 文章の食事（食事のサブセット）。自分の削除の印を持たないので、食事と一緒に消える
const sentTextMeals = sqliteTable(
  "sent_text_meals",
  {
    mealId: text("meal_id")
      .$type<RecordId>()
      .primaryKey()
      .references(() => mealTables.meals.id, { onDelete: "cascade" }),
    sentTextId: text("sent_text_id")
      .$type<RecordId>()
      .notNull()
      .references(() => sentTexts.id),
  },
  // 会話として送り直すときに、文章から作った食事を引くため
  (table) => [index("sent_text_meals_sent_text_id").on(table.sentTextId)],
);

// 推定が作った2つめ以降の文章の食事
const estimationCreatedMeals = sqliteTable("estimation_created_meals", {
  mealId: text("meal_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => sentTextMeals.mealId, { onDelete: "cascade" }),
  estimationId: text("estimation_id")
    .notNull()
    .references(() => estimationTables.estimations.id),
});

// 推定が決めた1つ目の文章の食事の時刻。meals.eaten_at は作ったときの時刻のまま書き換えない
const mealEatenAtEstimations = sqliteTable(
  "meal_eaten_at_estimations",
  {
    mealId: text("meal_id")
      .$type<RecordId>()
      .primaryKey()
      .references(() => sentTextMeals.mealId, { onDelete: "cascade" }),
    estimationId: text("estimation_id")
      .notNull()
      .references(() => estimationTables.estimations.id),
    eatenAt: integer("eaten_at", { mode: "timestamp_ms" }).notNull(),
  },
  // 時刻で食事を引く道の候補にするため
  (table) => [index("meal_eaten_at_estimations_eaten_at").on(table.eatenAt)],
);

// 送った文章と読み分け、文章の食事の表（#419）。宣言は durable-object-migrations/ の SQL に合わせる
export const sentTextTables = {
  sentTexts,
  sentTextClassifications,
  sentTextConversationResends,
  sentTextResends,
  conversationResendMealDeletions,
  sentTextMeals,
  estimationCreatedMeals,
  mealEatenAtEstimations,
};
