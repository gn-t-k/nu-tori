import type { RecordId } from "../../domain/record-id";

// 写真の宣言と、ファイルの受け取り・R2 から消した事実・写真の削除の印を読み書きする置き場
export type MealPhotoStore = {
  hasReceipt: (photoId: RecordId) => boolean;
  // 写真の削除の印だけを見る（宣言は見ない）
  hasDeletion: (photoId: RecordId) => boolean;
  // 受け取っていて、写真の削除の印が無い
  isKept: (photoId: RecordId) => boolean;
  insertReceipt: (photoId: RecordId, receivedAt: Date) => void;
  // 写真を宣言した食事。まだ宣言が届いていないか、消したとき undefined
  findMealIdOfPhoto: (photoId: RecordId) => RecordId | undefined;
  // 宣言した写真のうち、まだファイルを受け取っていないものがあるか
  hasUnreceivedPhotos: (mealId: RecordId) => boolean;
  // 消し残し: 受け取りがあり、写真の削除の印があり、R2 から消した事実が無い
  findLeftoverPhotoIds: () => RecordId[];
  insertFileDeletion: (photoId: RecordId, deletedAt: Date) => void;
};
