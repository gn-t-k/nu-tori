import { index, integer, real, sqliteTable, text } from "drizzle-orm/sqlite-core";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { mealTables } from "../../meal/durable-object/meal-tables";

const dishes = sqliteTable(
  "dishes",
  {
    id: text("id").primaryKey(),
    mealId: text("meal_id")
      .notNull()
      .references(() => mealTables.meals.id),
    name: text("name").notNull(),
    quantity: real("quantity").notNull(),
    unit: text("unit").notNull(),
    // 一意にしない。同じ並び順は ID の順で並べる
    positionInMeal: integer("position_in_meal").notNull(),
    version: integer("version").notNull(),
  },
  (table) => [index("dishes_meal_id").on(table.mealId, table.positionInMeal)],
);

// 料理の ID は値で名指しする（外部キーにしない）
const dishDeletions = sqliteTable("dish_deletions", {
  dishId: text("dish_id").primaryKey(),
});

const syncWriteDishDeletions = sqliteTable("sync_write_dish_deletions", {
  dishId: text("dish_id")
    .primaryKey()
    .references(() => dishDeletions.dishId),
  syncWriteReceiptId: text("sync_write_receipt_id")
    .notNull()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 料理の表。宣言は durable-object-migrations/ の SQL に合わせる
export const dishTables = {
  dishes,
  dishDeletions,
  syncWriteDishDeletions,
};
