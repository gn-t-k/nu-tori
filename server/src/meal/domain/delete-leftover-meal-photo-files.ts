import type { MealPhotoArchive } from "./meal-photo-archive";
import type { MealPhotoStore } from "./meal-photo-store";

// 消し残しを R2 から消し、消した事実を控える。R2 はトランザクションに入らないので、表から消し残しを出して消し直す。
// 失敗したら投げ、アラームのやり直しに任せる。消し終えた写真は控えたので、やり直しで消し直さない
export const deleteLeftoverMealPhotoFiles = async (
  store: MealPhotoStore,
  archive: MealPhotoArchive,
  deletedAt: Date,
): Promise<void> => {
  for (const photoId of store.findLeftoverPhotoIds()) {
    await archive.remove(photoId);
    store.insertFileDeletion(photoId, deletedAt);
  }
};
