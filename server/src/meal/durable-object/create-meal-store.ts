import { and, asc, between, eq, inArray } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import type { MealStore } from "../domain/meal-store";
import { mealPhotoTables } from "./meal-photo-tables";
import { mealTables } from "./meal-tables";

const { syncWriteReceipts } = syncLedgerTables;
const { meals, mealDeletions } = mealTables;
const { mealPhotos, mealPhotoDeletions } = mealPhotoTables;

export const createMealStore = (db: DrizzleSqliteDODatabase): MealStore => ({
  find: (id) => {
    const meal = db.select().from(meals).where(eq(meals.id, id)).get();
    if (meal === undefined) {
      return undefined;
    }
    const photos = db
      .select({ id: mealPhotos.id })
      .from(mealPhotos)
      .where(eq(mealPhotos.mealId, id))
      .orderBy(asc(mealPhotos.positionInMeal))
      .all();
    return { ...meal, photoIds: photos.map((photo) => photo.id) };
  },
  hasDeletion: (id) =>
    db
      .select({ id: mealDeletions.syncWriteReceiptId })
      .from(mealDeletions)
      .innerJoin(syncWriteReceipts, eq(syncWriteReceipts.id, mealDeletions.syncWriteReceiptId))
      .where(and(eq(syncWriteReceipts.recordType, "meal"), eq(syncWriteReceipts.recordId, id)))
      .all().length > 0,
  findUsedPhotoIds: (photoIds) => {
    const declared = db
      .select({ id: mealPhotos.id })
      .from(mealPhotos)
      .where(inArray(mealPhotos.id, [...photoIds]))
      .all();
    const deleted = db
      .select({ id: mealPhotoDeletions.mealPhotoId })
      .from(mealPhotoDeletions)
      .where(inArray(mealPhotoDeletions.mealPhotoId, [...photoIds]))
      .all();
    return [...declared, ...deleted].map((photo) => photo.id);
  },
  findEatenTimesBetween: (from, to) =>
    db
      .select({
        eatenAt: meals.eatenAt,
        eatenAtUtcOffsetSeconds: meals.eatenAtUtcOffsetSeconds,
      })
      .from(meals)
      .where(between(meals.eatenAt, from, to))
      .all(),
  insert: ({ photoIds, ...meal }) => {
    db.insert(meals).values(meal).run();
    db.insert(mealPhotos)
      .values(photoIds.map((id, positionInMeal) => ({ id, mealId: meal.id, positionInMeal })))
      .run();
  },
  remove: (id) => {
    db.delete(mealPhotos).where(eq(mealPhotos.mealId, id)).run();
    db.delete(meals).where(eq(meals.id, id)).run();
  },
  insertDeletion: (receiptId) => {
    db.insert(mealDeletions).values({ syncWriteReceiptId: receiptId.value }).run();
  },
  insertPhotoDeletions: (photoIds, receiptId) => {
    if (photoIds.length === 0) {
      return;
    }
    db.insert(mealPhotoDeletions)
      .values(photoIds.map((mealPhotoId) => ({ mealPhotoId, syncWriteReceiptId: receiptId.value })))
      .run();
  },
});
