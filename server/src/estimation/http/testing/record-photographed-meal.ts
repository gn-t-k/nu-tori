import { generateRecordId } from "../../../domain/record-id";
import { putMealPhoto } from "../../../http/meal-photo-routes/testing/put-meal-photo";
import { pushSyncWrites } from "../../../http/sync-routes/testing/push-sync-writes";
import { createMealWrite } from "../../../meal/http/testing/create-meal-write";

// 写真1枚の食事を送り、写真も送って、推定の予定に入れる。食事の ID を返す
export const recordPhotographedMeal = async (sessionToken: string): Promise<string> => {
  const mealId = generateRecordId();
  const photoId = generateRecordId();
  await pushSyncWrites(sessionToken, {
    writes: [createMealWrite({ meal: { id: mealId, photos: [{ id: photoId }] } })],
  });
  await putMealPhoto(sessionToken, photoId);
  return mealId;
};
