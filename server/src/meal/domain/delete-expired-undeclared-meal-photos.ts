import { computeUndeclaredMealPhotoExpiryAt } from "./compute-undeclared-meal-photo-expiry-at";
import type { MealPhotoArchive } from "./meal-photo-archive";
import type { MealPhotoStore } from "./meal-photo-store";

// 食事が届かないまま期限を過ぎた写真を R2 から消し、受け取りも消して、届いていない形に戻す（同じ写真がまた届いたら受け取る）。
// R2 を待つあいだに食事が届くことがあるので、1枚消すたびに表から出し直す。いま消している1枚に、その間に食事が届くことは防げない（受け取りを先に消すと、R2 から消せなかったファイルを消し直す手がかりが残らない）。
// 失敗したら投げ、アラームのやり直しに任せる。R2 から消して受け取りが残った写真は、やり直しで消す
export const deleteExpiredUndeclaredMealPhotos = async (
  store: MealPhotoStore,
  archive: MealPhotoArchive,
  now: Date,
): Promise<void> => {
  const findExpiredPhotoId = () =>
    store
      .findUndeclaredReceipts()
      .find(({ receivedAt }) => computeUndeclaredMealPhotoExpiryAt(receivedAt) <= now)?.photoId;
  for (let photoId = findExpiredPhotoId(); photoId !== undefined; photoId = findExpiredPhotoId()) {
    await archive.remove(photoId);
    store.deleteReceipt(photoId);
  }
};
