import type { RecordId } from "../../domain/record-id";
import type { MealPhotoArchive } from "./meal-photo-archive";
import type { MealPhotoStore } from "./meal-photo-store";

// 受け取っていて、消していない写真の縮小版。消し残しは R2 にまだあっても返さない
export const readKeptMealPhoto = async (
  store: MealPhotoStore,
  archive: MealPhotoArchive,
  photoId: RecordId,
): Promise<ArrayBuffer | undefined> => (store.isKept(photoId) ? archive.read(photoId) : undefined);
