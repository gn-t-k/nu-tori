import type { RecordId } from "../../domain/record-id";

// 写真の控え（縮小版のファイル）の置き場。アカウントごとに作る
export type MealPhotoArchive = {
  put: (photoId: RecordId, photo: ArrayBuffer) => Promise<void>;
  // 無ければ undefined
  read: (photoId: RecordId) => Promise<ArrayBuffer | undefined>;
  // 無くても失敗しない
  remove: (photoId: RecordId) => Promise<void>;
};
