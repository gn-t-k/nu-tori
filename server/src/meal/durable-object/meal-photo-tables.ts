import { integer, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { mealTables } from "./meal-tables";

const mealPhotos = sqliteTable(
  "meal_photos",
  {
    id: text("id").primaryKey(),
    mealId: text("meal_id")
      .notNull()
      .references(() => mealTables.meals.id),
    positionInMeal: integer("position_in_meal").notNull(),
  },
  (table) => [uniqueIndex("meal_photos_position").on(table.mealId, table.positionInMeal)],
);

// 写真の ID は値で名指しする（外部キーにしない）。宣言より先にも後にも届き、食事を消したあとも R2 の消し残しを出すために残る
const mealPhotoFileReceipts = sqliteTable("meal_photo_file_receipts", {
  mealPhotoId: text("meal_photo_id").primaryKey(),
  receivedAt: integer("received_at", { mode: "timestamp_ms" }).notNull(),
});

const mealPhotoFileDeletions = sqliteTable("meal_photo_file_deletions", {
  mealPhotoId: text("meal_photo_id")
    .primaryKey()
    .references(() => mealPhotoFileReceipts.mealPhotoId),
  deletedAt: integer("deleted_at", { mode: "timestamp_ms" }).notNull(),
});

const mealPhotoDeletions = sqliteTable("meal_photo_deletions", {
  mealPhotoId: text("meal_photo_id").primaryKey(),
  syncWriteReceiptId: text("sync_write_receipt_id")
    .notNull()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 写真の表（宣言、ファイルの受け取りと R2 から消した事実、宣言の削除の印）。宣言は durable-object-migrations/ の SQL に合わせる
export const mealPhotoTables = {
  mealPhotos,
  mealPhotoFileReceipts,
  mealPhotoFileDeletions,
  mealPhotoDeletions,
};
