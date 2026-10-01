import { and, eq, isNull } from "drizzle-orm";
import type { DrizzleSqliteDODatabase } from "drizzle-orm/durable-sqlite";
import type { MealPhotoStore } from "../domain/meal-photo-store";
import { mealPhotoTables } from "./meal-photo-tables";

const { mealPhotos, mealPhotoFileReceipts, mealPhotoFileDeletions, mealPhotoDeletions } =
  mealPhotoTables;

export const createMealPhotoStore = (db: DrizzleSqliteDODatabase): MealPhotoStore => ({
  hasReceipt: (photoId) =>
    db
      .select({ id: mealPhotoFileReceipts.mealPhotoId })
      .from(mealPhotoFileReceipts)
      .where(eq(mealPhotoFileReceipts.mealPhotoId, photoId))
      .get() !== undefined,
  hasDeletion: (photoId) =>
    db
      .select({ id: mealPhotoDeletions.mealPhotoId })
      .from(mealPhotoDeletions)
      .where(eq(mealPhotoDeletions.mealPhotoId, photoId))
      .get() !== undefined,
  isKept: (photoId) =>
    db
      .select({ id: mealPhotoFileReceipts.mealPhotoId })
      .from(mealPhotoFileReceipts)
      .leftJoin(
        mealPhotoDeletions,
        eq(mealPhotoDeletions.mealPhotoId, mealPhotoFileReceipts.mealPhotoId),
      )
      .where(
        and(eq(mealPhotoFileReceipts.mealPhotoId, photoId), isNull(mealPhotoDeletions.mealPhotoId)),
      )
      .get() !== undefined,
  insertReceipt: (photoId, receivedAt) => {
    db.insert(mealPhotoFileReceipts).values({ mealPhotoId: photoId, receivedAt }).run();
  },
  findMealIdOfPhoto: (photoId) =>
    db
      .select({ mealId: mealPhotos.mealId })
      .from(mealPhotos)
      .where(eq(mealPhotos.id, photoId))
      .get()?.mealId,
  hasUnreceivedPhotos: (mealId) =>
    db
      .select({ id: mealPhotos.id })
      .from(mealPhotos)
      .leftJoin(mealPhotoFileReceipts, eq(mealPhotoFileReceipts.mealPhotoId, mealPhotos.id))
      .where(and(eq(mealPhotos.mealId, mealId), isNull(mealPhotoFileReceipts.mealPhotoId)))
      .get() !== undefined,
  findLeftoverPhotoIds: () =>
    db
      .select({ id: mealPhotoFileReceipts.mealPhotoId })
      .from(mealPhotoFileReceipts)
      .innerJoin(
        mealPhotoDeletions,
        eq(mealPhotoDeletions.mealPhotoId, mealPhotoFileReceipts.mealPhotoId),
      )
      .leftJoin(
        mealPhotoFileDeletions,
        eq(mealPhotoFileDeletions.mealPhotoId, mealPhotoFileReceipts.mealPhotoId),
      )
      .where(isNull(mealPhotoFileDeletions.mealPhotoId))
      .all()
      .map(({ id }) => id),
  // 消し直しは R2 を待つあいだにほかの呼び出しと重なりうるので、先に控えたほうを残す
  insertFileDeletion: (photoId, deletedAt) => {
    db.insert(mealPhotoFileDeletions)
      .values({ mealPhotoId: photoId, deletedAt })
      .onConflictDoNothing()
      .run();
  },
});
