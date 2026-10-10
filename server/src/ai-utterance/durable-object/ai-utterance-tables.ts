import { integer, primaryKey, sqliteTable, text } from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { replyTables } from "../../reply/durable-object/reply-tables";

// 返事。記録の ID は返事の生成の ID と同じ
const aiUtterances = sqliteTable("ai_utterances", {
  replyGenerationId: text("reply_generation_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => replyTables.replyGenerations.id),
  body: text("body").notNull(),
});

// 指し示す食事。食事を消しても指し示しを残すので、食事を外部キーで指さず値で名指しする
const aiUtteranceMeals = sqliteTable(
  "ai_utterance_meals",
  {
    aiUtteranceId: text("ai_utterance_id")
      .$type<RecordId>()
      .notNull()
      .references(() => aiUtterances.replyGenerationId),
    mealId: text("meal_id").$type<RecordId>().notNull(),
    positionInUtterance: integer("position_in_utterance").notNull(),
  },
  (table) => [primaryKey({ columns: [table.aiUtteranceId, table.mealId] })],
);

// 返事の表（#419）。宣言は durable-object-migrations/ の SQL に合わせる
export const aiUtteranceTables = {
  aiUtterances,
  aiUtteranceMeals,
};
