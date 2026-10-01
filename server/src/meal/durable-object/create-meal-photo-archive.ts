import type { MealPhotoArchive } from "../domain/meal-photo-archive";
import { computeMealPhotoKeyPrefix } from "./compute-meal-photo-key-prefix";

export const createMealPhotoArchive = (bucket: R2Bucket, accountId: string): MealPhotoArchive => {
  const keyOf = (photoId: string) => `${computeMealPhotoKeyPrefix(accountId)}${photoId}`;
  return {
    put: async (photoId, photo) => {
      await bucket.put(keyOf(photoId), photo);
    },
    read: async (photoId) => (await bucket.get(keyOf(photoId)))?.arrayBuffer(),
    remove: (photoId) => bucket.delete(keyOf(photoId)),
  };
};
