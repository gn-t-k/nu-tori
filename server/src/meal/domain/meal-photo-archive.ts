// 写真の控え（縮小版のファイル）の置き場。アカウントごとに作る
export type MealPhotoArchive = {
  put: (photoId: string, photo: ArrayBuffer) => Promise<void>;
  // 無ければ undefined
  read: (photoId: string) => Promise<ArrayBuffer | undefined>;
  // 無くても失敗しない
  remove: (photoId: string) => Promise<void>;
};
