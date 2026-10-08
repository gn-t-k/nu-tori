import { and, desc, eq } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { generateRecordId, type RecordId } from "../../domain/record-id";
import { dishTables } from "../../dish/durable-object/dish-tables";
import { findNewestDishEstimationId } from "../../dish/durable-object/find-newest-dish-estimation-id";
import { isNutrientName } from "../../domain/food-composition/nutrient-name";
import { findLatestCorrection } from "../../durable-object/find-latest-correction";
import { removeCorrectionsOfRecord } from "../../durable-object/remove-corrections-of-record";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import type { Ingredient, IngredientNutrientSource } from "../domain/ingredient";
import type { IngredientStore } from "../domain/ingredient-store";
import { ingredientTables } from "./ingredient-tables";

const { dishes, dishQuantityCorrectionIngredients } = dishTables;
const { syncWriteRecordChanges } = syncLedgerTables;
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
      ...findCurrentQuantity(db, found.ingredient),
      nutrientSource: toNutrientSource(found),
      // 名前は書くときに確かめているが、項目を減らしたあとの古い行は読み飛ばす
      nutrients: Object.fromEntries(
        nutrients.flatMap(({ nutrient, amount }) =>
          isNutrientName(nutrient) ? [[nutrient, amount]] : [],
        ),
      ),
    };
  },
  hasDeletion: (id) =>
    db
      .select({ id: ingredientDeletions.ingredientId })
      .from(ingredientDeletions)
      .where(eq(ingredientDeletions.ingredientId, id))
      .get() !== undefined || isReplaced(db, id),
  isReplaced: (id) => isReplaced(db, id),
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
  findCurrentIdsOfDish: (dishId) => {
    const estimationId = findNewestDishEstimationId(db, dishId);
    if (estimationId === undefined) {
      return [];
    }
    return db
      .select({ id: ingredients.id })
      .from(ingredients)
      .where(and(eq(ingredients.dishId, dishId), eq(ingredients.estimationId, estimationId)))
      .all()
      .map(({ id }) => id);
  },
  insert: ({ nutrientSource, nutrients, ...ingredient }) => {
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
        .values({ id: generateRecordId(), ingredientId: ingredient.id, nutrient, amountPerBasis })
        .run();
    }
  },
  insertQuantityCorrection: (receiptId, quantity) => {
    db.insert(ingredientQuantityCorrections)
      .values({ syncWriteReceiptId: receiptId.value, quantity })
      .run();
  },
  remove: (ids) => {
    for (const id of ids) {
      db.delete(ingredients).where(eq(ingredients.id, id)).run();
    }
  },
  removeCorrections: (ids) => {
    for (const id of ids) {
      removeCorrectionsOfRecord(db, ingredientQuantityCorrections, {
        recordType: "ingredient",
        recordId: id,
      });
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

// 推定し直しで置き換わった前の推定の材料（行は残る）
const isReplaced = (db: DrizzleSqliteDODatabase, id: RecordId): boolean => {
  const ingredient = db
    .select({ dishId: ingredients.dishId, estimationId: ingredients.estimationId })
    .from(ingredients)
    .where(eq(ingredients.id, id))
    .get();
  return ingredient !== undefined && !isCurrent(db, ingredient);
};

// 今の材料は、料理のいちばん新しい当てた推定の材料。前の推定の材料は、行が残っても削除の印として届ける
const isCurrent = (
  db: DrizzleSqliteDODatabase,
  { dishId, estimationId }: { dishId: RecordId; estimationId: string },
): boolean => findNewestDishEstimationId(db, dishId) === estimationId;

// 今の量は、材料を直した量（材料を書き換えた控えの修正）と、料理の量に比例させた量（料理を書き換えた控えの明細）を合わせて、
// 受け取った順（控えを当てたときの変更の通し番号）でいちばんあとのもの。どちらも無ければ推定した量。
// 出どころは、材料を直した量があれば直した（比例は推定したまま）
const findCurrentQuantity = (
  db: DrizzleSqliteDODatabase,
  ingredient: { id: RecordId; quantity: number },
): Pick<Ingredient, "quantity" | "quantitySource"> => {
  const corrected = findLatestCorrection(db, ingredientQuantityCorrections, "quantity", {
    recordType: "ingredient",
    recordId: ingredient.id,
  });
  const proportioned = db
    .select({
      quantity: dishQuantityCorrectionIngredients.quantity,
      sequence: syncWriteRecordChanges.recordChangeSequence,
    })
    .from(dishQuantityCorrectionIngredients)
    .innerJoin(
      syncWriteRecordChanges,
      eq(
        syncWriteRecordChanges.syncWriteReceiptId,
        dishQuantityCorrectionIngredients.syncWriteReceiptId,
      ),
    )
    .where(eq(dishQuantityCorrectionIngredients.ingredientId, ingredient.id))
    .orderBy(desc(syncWriteRecordChanges.recordChangeSequence))
    .limit(1)
    .get();
  const latest = [
    corrected === undefined
      ? undefined
      : { quantity: corrected.value, sequence: corrected.sequence },
    proportioned,
  ]
    .filter((found) => found !== undefined)
    .toSorted((a, b) => b.sequence - a.sequence)[0];
  return {
    quantity: latest?.quantity ?? ingredient.quantity,
    quantitySource: corrected === undefined ? "estimated" : "corrected",
  };
};

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
