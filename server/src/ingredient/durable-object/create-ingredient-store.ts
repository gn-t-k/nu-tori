import { and, eq, inArray } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { dishTables } from "../../dish/durable-object/dish-tables";
import { findNewestDishEstimationId } from "../../dish/durable-object/find-newest-dish-estimation";
import { isNutrientName } from "../../domain/food-composition/nutrient-name";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import type { Ingredient, IngredientNutrientSource } from "../domain/ingredient";
import type { IngredientStore } from "../domain/ingredient-store";
import { ingredientTables } from "./ingredient-tables";

const { dishes } = dishTables;
const { syncWriteReceipts } = syncLedgerTables;
const {
  ingredients,
  foodCompositionIngredients,
  nutritionLabelIngredients,
  ingredientNutrients,
  ingredientQuantityCorrections,
  ingredientDeletions,
} = ingredientTables;

// 材料の ID は食事の数ほど届きうるので、変数の上限（100）を超えないよう1行ずつ消し・書く
export const createIngredientStore = (db: DrizzleSqliteDODatabase): IngredientStore => ({
  find: (id) => {
    const found = db
      .select({
        ingredient: ingredients,
        foodNumber: foodCompositionIngredients.foodNumber,
        labelBasisGrams: nutritionLabelIngredients.labelBasisGrams,
      })
      .from(ingredients)
      .leftJoin(
        foodCompositionIngredients,
        eq(foodCompositionIngredients.ingredientId, ingredients.id),
      )
      .leftJoin(
        nutritionLabelIngredients,
        eq(nutritionLabelIngredients.ingredientId, ingredients.id),
      )
      .where(eq(ingredients.id, id))
      .get();
    if (found === undefined || !isCurrent(db, found.ingredient)) {
      return undefined;
    }
    const nutrients = db
      .select({
        nutrient: ingredientNutrients.nutrient,
        amount: ingredientNutrients.amountPerBasis,
      })
      .from(ingredientNutrients)
      .where(eq(ingredientNutrients.ingredientId, id))
      .all();
    return {
      ...found.ingredient,
      nutrientSource: toNutrientSource(found),
      // 名前は書くときに確かめているが、項目を減らしたあとの古い行は読み飛ばす
      nutrients: Object.fromEntries(
        nutrients.flatMap(({ nutrient, amount }) =>
          isNutrientName(nutrient) ? [[nutrient, amount]] : [],
        ),
      ),
    };
  },
  hasDeletion: (id) => {
    const deletion = db
      .select({ id: ingredientDeletions.ingredientId })
      .from(ingredientDeletions)
      .where(eq(ingredientDeletions.ingredientId, id))
      .get();
    if (deletion !== undefined) {
      return true;
    }
    const ingredient = db
      .select({ dishId: ingredients.dishId, estimationId: ingredients.estimationId })
      .from(ingredients)
      .where(eq(ingredients.id, id))
      .get();
    return ingredient !== undefined && !isCurrent(db, ingredient);
  },
  findIdsOfMeal: (mealId) =>
    db
      .select({ id: ingredients.id })
      .from(ingredients)
      .innerJoin(dishes, eq(dishes.id, ingredients.dishId))
      .where(eq(dishes.mealId, mealId))
      .all()
      .map(({ id }) => id),
  findIdsOfDish: (dishId) =>
    db
      .select({ id: ingredients.id })
      .from(ingredients)
      .where(eq(ingredients.dishId, dishId))
      .all()
      .map(({ id }) => id),
  insert: ({ nutrientSource, nutrients, ...ingredient }: Ingredient) => {
    db.insert(ingredients).values(ingredient).run();
    if (nutrientSource.type === "food_composition") {
      db.insert(foodCompositionIngredients)
        .values({ ingredientId: ingredient.id, foodNumber: nutrientSource.foodNumber })
        .run();
    }
    if (nutrientSource.type === "nutrition_label") {
      db.insert(nutritionLabelIngredients)
        .values({ ingredientId: ingredient.id, labelBasisGrams: nutrientSource.labelBasisGrams })
        .run();
    }
    for (const [nutrient, amountPerBasis] of Object.entries(nutrients)) {
      db.insert(ingredientNutrients)
        .values({ id: crypto.randomUUID(), ingredientId: ingredient.id, nutrient, amountPerBasis })
        .run();
    }
  },
  remove: (ids) => {
    for (const id of ids) {
      db.delete(ingredients).where(eq(ingredients.id, id)).run();
    }
  },
  removeCorrections: (ids) => {
    for (const id of ids) {
      db.delete(ingredientQuantityCorrections)
        .where(
          inArray(
            ingredientQuantityCorrections.syncWriteReceiptId,
            db
              .select({ id: syncWriteReceipts.id })
              .from(syncWriteReceipts)
              .where(
                and(
                  eq(syncWriteReceipts.recordType, "ingredient"),
                  eq(syncWriteReceipts.recordId, id),
                ),
              ),
          ),
        )
        .run();
    }
  },
  insertDeletions: (ids, receiptId) => {
    for (const ingredientId of ids) {
      db.insert(ingredientDeletions)
        .values({ ingredientId, syncWriteReceiptId: receiptId.value })
        .run();
    }
  },
});

// 今の材料は、料理のいちばん新しい当てた推定の材料。前の推定の材料は、行が残っても削除の印として届ける
const isCurrent = (
  db: DrizzleSqliteDODatabase,
  { dishId, estimationId }: { dishId: string; estimationId: string },
): boolean => findNewestDishEstimationId(db, dishId) === estimationId;

// 出どころは、サブセットの表の行があるかで出す
const toNutrientSource = ({
  foodNumber,
  labelBasisGrams,
}: {
  foodNumber: string | null;
  labelBasisGrams: number | null;
}): IngredientNutrientSource => {
  if (labelBasisGrams !== null) {
    return { type: "nutrition_label", labelBasisGrams };
  }
  if (foodNumber !== null) {
    return { type: "food_composition", foodNumber };
  }
  return { type: "estimated" };
};
