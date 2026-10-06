import {
  type AnySQLiteColumn,
  foreignKey,
  index,
  integer,
  primaryKey,
  real,
  sqliteTable,
  text,
} from "drizzle-orm/sqlite-core";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { estimationTables } from "../../estimation/durable-object/estimation-tables";
import { ingredientTables } from "../../ingredient/durable-object/ingredient-tables";
import { mealTables } from "../../meal/durable-object/meal-tables";

// 名前は作ったときの名前で、書き換えない。量と単位は当てた推定と修正の行から、版は出来事の数から出す（#332 の Schema changes）
const dishes = sqliteTable(
  "dishes",
  {
    id: text("id").primaryKey(),
    mealId: text("meal_id")
      .notNull()
      .references(() => mealTables.meals.id),
    name: text("name").notNull(),
    // 一意にしない。同じ並び順は ID の順で並べる
    positionInMeal: integer("position_in_meal").notNull(),
  },
  (table) => [index("dishes_meal_id").on(table.mealId, table.positionInMeal)],
);

// 推定の結果を料理に当てたこと。材料は当てた推定に属する
const dishEstimationApplications = sqliteTable(
  "dish_estimation_applications",
  {
    dishId: text("dish_id")
      .notNull()
      .references(() => dishes.id, { onDelete: "cascade" }),
    estimationId: text("estimation_id")
      .notNull()
      .references(() => estimationTables.estimations.id),
  },
  (table) => [primaryKey({ columns: [table.dishId, table.estimationId] })],
);

// 当てた推定の量と単位。量の無い推定（通らなかった）は行を持たない
const dishEstimatedQuantities = sqliteTable(
  "dish_estimated_quantities",
  {
    dishId: text("dish_id").notNull(),
    estimationId: text("estimation_id").notNull(),
    quantity: real("quantity").notNull(),
    unit: text("unit").notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.dishId, table.estimationId] }),
    foreignKey({
      columns: [table.dishId, table.estimationId],
      foreignColumns: [dishEstimationApplications.dishId, dishEstimationApplications.estimationId],
    }).onDelete("cascade"),
  ],
);

// 修正の行は控えだけを指す。料理は控えの record_id で、料理を消す口が控えから探して消す
const dishNameCorrections = sqliteTable("dish_name_corrections", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
  name: text("name").notNull(),
});

const dishQuantityCorrections = sqliteTable("dish_quantity_corrections", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
  quantity: real("quantity").notNull(),
});

// 料理の量を直したときに、材料の量を同じ割合で変えた明細（比例）
const dishQuantityCorrectionIngredients = sqliteTable(
  "dish_quantity_correction_ingredients",
  {
    syncWriteReceiptId: text("sync_write_receipt_id")
      .notNull()
      .references(() => dishQuantityCorrections.syncWriteReceiptId, { onDelete: "cascade" }),
    // 材料の表がこの表の束を指し返すので、型の推論が循環しないよう参照先の型を書く
    ingredientId: text("ingredient_id")
      .notNull()
      .references((): AnySQLiteColumn => ingredientTables.ingredients.id, { onDelete: "cascade" }),
    quantity: real("quantity").notNull(),
  },
  (table) => [
    primaryKey({ columns: [table.syncWriteReceiptId, table.ingredientId] }),
    index("dish_quantity_correction_ingredients_ingredient_id").on(table.ingredientId),
  ],
);

// 料理が対象の推定の予定のつなぎ。料理を消すとつなぎだけが消え、予定と推定は残る
const dishEstimationSchedules = sqliteTable(
  "dish_estimation_schedules",
  {
    estimationScheduleId: text("estimation_schedule_id")
      .primaryKey()
      .references(() => estimationTables.estimationSchedules.id),
    dishId: text("dish_id")
      .notNull()
      .references(() => dishes.id, { onDelete: "cascade" }),
  },
  (table) => [index("dish_estimation_schedules_dish_id").on(table.dishId)],
);

// 料理の ID は値で名指しする（外部キーにしない）
const dishDeletions = sqliteTable("dish_deletions", {
  dishId: text("dish_id").primaryKey(),
  syncWriteReceiptId: text("sync_write_receipt_id")
    .notNull()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 料理の表。宣言は durable-object-migrations/ の SQL に合わせる
export const dishTables = {
  dishes,
  dishEstimationApplications,
  dishEstimatedQuantities,
  dishNameCorrections,
  dishQuantityCorrections,
  dishQuantityCorrectionIngredients,
  dishEstimationSchedules,
  dishDeletions,
};
