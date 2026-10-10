import { and, asc, between, eq, inArray } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { RecordId } from "../../domain/record-id";
import { findLatestCorrection } from "../../durable-object/find-latest-correction";
import { removeCorrectionsOfRecord } from "../../durable-object/remove-corrections-of-record";
import { syncLedgerTables } from "../../durable-object/sync-ledger-tables";
import { sentTextTables } from "../../sent-text/durable-object/sent-text-tables";
import type { MealStore } from "../domain/meal-store";
import { mealPhotoTables } from "./meal-photo-tables";
import { mealTables } from "./meal-tables";

const { syncWriteReceipts } = syncLedgerTables;
const { meals, mealEatenAtCorrections, mealDeletions } = mealTables;
const { mealPhotos, mealPhotoDeletions } = mealPhotoTables;
const { sentTextMeals } = sentTextTables;

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
    return {
      ...meal,
      eatenAt: findCorrectedEatenAt(db, id) ?? meal.eatenAt,
      photoIds: photos.map((photo) => photo.id),
      sentTextId: db
        .select({ sentTextId: sentTextMeals.sentTextId })
        .from(sentTextMeals)
        .where(eq(sentTextMeals.mealId, id))
        .get()?.sentTextId,
    };
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
  // #332 の「時刻で食事を引く道」: 作ったときの時刻と直した時刻の両方から候補を出し、候補ごとに今の時刻を出してから範囲で絞る。
  // 作ったときの時刻だけで引くと、直して日をまたいだ食事を数え誤る
  findEatenTimesBetween: (from, to) => {
    const createdInRange = db
      .select({ id: meals.id })
      .from(meals)
      .where(between(meals.eatenAt, from, to))
      .all();
    const correctedInRange = db
      .select({ id: meals.id })
      .from(mealEatenAtCorrections)
      .innerJoin(
        syncWriteReceipts,
        eq(syncWriteReceipts.id, mealEatenAtCorrections.syncWriteReceiptId),
      )
      .innerJoin(
        meals,
        and(eq(syncWriteReceipts.recordType, "meal"), eq(meals.id, syncWriteReceipts.recordId)),
      )
      .where(between(mealEatenAtCorrections.eatenAt, from, to))
      .all();
    const candidateIds = new Set([...createdInRange, ...correctedInRange].map(({ id }) => id));
    return [...candidateIds].flatMap((id) => {
      const meal = db
        .select({
          eatenAt: meals.eatenAt,
          eatenAtUtcOffsetSeconds: meals.eatenAtUtcOffsetSeconds,
        })
        .from(meals)
        .where(eq(meals.id, id))
        .get();
      if (meal === undefined) {
        return [];
      }
      const eatenAt = findCorrectedEatenAt(db, id) ?? meal.eatenAt;
      return eatenAt >= from && eatenAt <= to
        ? [{ eatenAt, eatenAtUtcOffsetSeconds: meal.eatenAtUtcOffsetSeconds }]
        : [];
    });
  },
  insert: ({ photoIds, sentTextId, ...meal }) => {
    db.insert(meals).values(meal).run();
    if (photoIds.length > 0) {
      db.insert(mealPhotos)
        .values(photoIds.map((id, positionInMeal) => ({ id, mealId: meal.id, positionInMeal })))
        .run();
    }
    if (sentTextId !== undefined) {
      db.insert(sentTextMeals).values({ mealId: meal.id, sentTextId }).run();
    }
  },
  insertEatenAtCorrection: (receiptId, eatenAt) => {
    db.insert(mealEatenAtCorrections)
      .values({ syncWriteReceiptId: receiptId.value, eatenAt })
      .run();
  },
  removeCorrections: (id) => {
    removeCorrectionsOfRecord(db, mealEatenAtCorrections, { recordType: "meal", recordId: id });
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

const findCorrectedEatenAt = (db: DrizzleSqliteDODatabase, id: RecordId): Date | undefined =>
  findLatestCorrection(db, mealEatenAtCorrections, "eatenAt", {
    recordType: "meal",
    recordId: id,
  })?.value;

// Durable Object の SQLite は、1つのクエリに渡せる変数が 100 まで。受け付けなかった書き込みの写真の ID は、いくつでも届きうる
const splitIntoQueryableChunks = (ids: readonly RecordId[]): RecordId[][] => {
  const maximumVariablesPerQuery = 100;
  return Array.from({ length: Math.ceil(ids.length / maximumVariablesPerQuery) }, (_, index) =>
    ids.slice(index * maximumVariablesPerQuery, (index + 1) * maximumVariablesPerQuery),
  );
};
