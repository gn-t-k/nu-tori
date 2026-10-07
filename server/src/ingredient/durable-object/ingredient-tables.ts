import {
  foreignKey,
  index,
  integer,
  real,
  sqliteTable,
  text,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";
import type { RecordId } from "../../domain/record-id";
import { dishTables } from "../../dish/durable-object/dish-tables";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";

const ingredients = sqliteTable(
  "ingredients",
  {
    id: text("id").$type<RecordId>().primaryKey(),
    // 料理と推定の組で、当てた推定を指す。料理だけを指す外部キーは持たない
    dishId: text("dish_id").$type<RecordId>().notNull(),
    estimationId: text("estimation_id").notNull(),
    name: text("name").notNull(),
    // 推定した量。書き換えない
    quantity: real("quantity").notNull(),
    unit: text("unit").notNull(),
    edibleGramsPerUnit: real("edible_grams_per_unit").notNull(),
    // 一意にしない。同じ並び順は ID の順で並べる
    positionInDish: integer("position_in_dish").notNull(),
  },
  (table) => [
    index("ingredients_application").on(table.dishId, table.estimationId, table.positionInDish),
    // NO ACTION。材料を消さずに当てた推定（料理）を消すと止まる
    foreignKey({
      columns: [table.dishId, table.estimationId],
      foreignColumns: [
        dishTables.dishEstimationApplications.dishId,
        dishTables.dishEstimationApplications.estimationId,
      ],
    }),
  ],
);

// 出どころのサブセットと栄養の値は自分の削除の印を持たないので、材料を消すと CASCADE で消える
const foodCompositionIngredients = sqliteTable("food_composition_ingredients", {
  ingredientId: text("ingredient_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => ingredients.id, { onDelete: "cascade" }),
  // 先頭の 0 を落とさないよう TEXT で持つ
  foodNumber: text("food_number").notNull(),
});

const nutritionLabelIngredients = sqliteTable("nutrition_label_ingredients", {
  ingredientId: text("ingredient_id")
    .$type<RecordId>()
    .primaryKey()
    .references(() => ingredients.id, { onDelete: "cascade" }),
  labelBasisGrams: real("label_basis_grams").notNull(),
});

const ingredientNutrients = sqliteTable(
  "ingredient_nutrients",
  {
    id: text("id").primaryKey(),
    ingredientId: text("ingredient_id")
      .$type<RecordId>()
      .notNull()
      .references(() => ingredients.id, { onDelete: "cascade" }),
    // 項目の名前の集合は shared/nutrients.json。単位は名前に含む
    nutrient: text("nutrient").notNull(),
    amountPerBasis: real("amount_per_basis").notNull(),
  },
  (table) => [uniqueIndex("ingredient_nutrients_nutrient").on(table.ingredientId, table.nutrient)],
);

// 修正の行は控えだけを指す。材料は控えの record_id で、料理を消す口が控えから探して消す
const ingredientQuantityCorrections = sqliteTable("ingredient_quantity_corrections", {
  syncWriteReceiptId: text("sync_write_receipt_id")
    .primaryKey()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
  quantity: real("quantity").notNull(),
});

// 材料の ID は値で名指しする（外部キーにしない）
const ingredientDeletions = sqliteTable("ingredient_deletions", {
  ingredientId: text("ingredient_id").$type<RecordId>().primaryKey(),
  syncWriteReceiptId: text("sync_write_receipt_id")
    .notNull()
    .references(() => syncLedgerTables.syncWriteReceipts.id),
});

// 材料の表（出どころのサブセットと栄養の値を含む）。宣言は durable-object-migrations/ の SQL に合わせる
export const ingredientTables = {
  ingredients,
  foodCompositionIngredients,
  nutritionLabelIngredients,
  ingredientNutrients,
  ingredientQuantityCorrections,
  ingredientDeletions,
};
