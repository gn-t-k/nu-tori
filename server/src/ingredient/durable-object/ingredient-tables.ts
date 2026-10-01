import { index, integer, real, sqliteTable, text, uniqueIndex } from "drizzle-orm/sqlite-core";
import { dishTables } from "../../dish/durable-object/dish-tables";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";

const ingredients = sqliteTable(
  "ingredients",
  {
    id: text("id").primaryKey(),
    dishId: text("dish_id")
      .notNull()
      .references(() => dishTables.dishes.id),
    name: text("name").notNull(),
    quantity: real("quantity").notNull(),
    unit: text("unit").notNull(),
    edibleGramsPerUnit: real("edible_grams_per_unit").notNull(),
    // 一意にしない。同じ並び順は ID の順で並べる
    positionInDish: integer("position_in_dish").notNull(),
  },
  (table) => [index("ingredients_dish_id").on(table.dishId, table.positionInDish)],
);

// 出どころのサブセットと栄養の値は自分の削除の印を持たないので、材料を消すと CASCADE で消える
const foodCompositionIngredients = sqliteTable("food_composition_ingredients", {
  ingredientId: text("ingredient_id")
    .primaryKey()
    .references(() => ingredients.id, { onDelete: "cascade" }),
  // 先頭の 0 を落とさないよう TEXT で持つ
  foodNumber: text("food_number").notNull(),
});

const nutritionLabelIngredients = sqliteTable("nutrition_label_ingredients", {
  ingredientId: text("ingredient_id")
    .primaryKey()
    .references(() => ingredients.id, { onDelete: "cascade" }),
  labelBasisGrams: real("label_basis_grams").notNull(),
});

const ingredientNutrients = sqliteTable(
  "ingredient_nutrients",
  {
    id: text("id").primaryKey(),
    ingredientId: text("ingredient_id")
      .notNull()
      .references(() => ingredients.id, { onDelete: "cascade" }),
    // 項目の名前の集合は shared/nutrients.json。単位は名前に含む
    nutrient: text("nutrient").notNull(),
    amountPerBasis: real("amount_per_basis").notNull(),
  },
  (table) => [uniqueIndex("ingredient_nutrients_nutrient").on(table.ingredientId, table.nutrient)],
);

// 材料の ID は値で名指しする（外部キーにしない）
const ingredientDeletions = sqliteTable("ingredient_deletions", {
  ingredientId: text("ingredient_id").primaryKey(),
});

const syncWriteIngredientDeletions = sqliteTable("sync_write_ingredient_deletions", {
  ingredientId: text("ingredient_id")
    .primaryKey()
    .references(() => ingredientDeletions.ingredientId),
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
  ingredientDeletions,
  syncWriteIngredientDeletions,
};
