import { and, asc, between, eq, inArray } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import type { MealStore } from "../domain/meal-store";
import { mealPhotoTables } from "./meal-photo-tables";
import { mealTables } from "./meal-tables";

const { syncWriteReceipts } = syncLedgerTables;
const { meals, mealEatenAtCorrections, mealDeletions } = mealTables;
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
  findUsedPhotoIds: (photoIds) =>
    splitIntoQueryableChunks(photoIds).flatMap((chunk) => [
      ...db
        .select({ id: mealPhotos.id })
        .from(mealPhotos)
        .where(inArray(mealPhotos.id, chunk))
        .all()
        .map((photo) => photo.id),
      ...db
        .select({ id: mealPhotoDeletions.mealPhotoId })
        .from(mealPhotoDeletions)
        .where(inArray(mealPhotoDeletions.mealPhotoId, chunk))
        .all()
        .map((photo) => photo.id),
    ]),
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
  removeCorrections: (id) => {
    db.delete(mealEatenAtCorrections)
      .where(
        inArray(
          mealEatenAtCorrections.syncWriteReceiptId,
          db
            .select({ id: syncWriteReceipts.id })
            .from(syncWriteReceipts)
            .where(
              and(eq(syncWriteReceipts.recordType, "meal"), eq(syncWriteReceipts.recordId, id)),
            ),
        ),
      )
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
    // 1行ずつ書き、受け付けなかった書き込みの写真の ID がいくつあっても、変数の上限を超えないようにする
    for (const mealPhotoId of photoIds) {
      db.insert(mealPhotoDeletions)
        .values({ mealPhotoId, syncWriteReceiptId: receiptId.value })
        .run();
    }
  },
});

// Durable Object の SQLite は、1つのクエリに渡せる変数が 100 まで。受け付けなかった書き込みの写真の ID は、いくつでも届きうる
const splitIntoQueryableChunks = (ids: readonly string[]): string[][] => {
  const maximumVariablesPerQuery = 100;
  return Array.from({ length: Math.ceil(ids.length / maximumVariablesPerQuery) }, (_, index) =>
    ids.slice(index * maximumVariablesPerQuery, (index + 1) * maximumVariablesPerQuery),
  );
};
