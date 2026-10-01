import { computeMealPhotoKeyPrefix } from "./compute-meal-photo-key-prefix";

// アカウントの削除で、写真の控えを接頭辞で頁ごとに一覧し、まとめて消す。Durable Object の表を読まない
export const deleteMealPhotoFilesOfAccount = async (
  bucket: R2Bucket,
  accountId: string,
): Promise<void> => {
  const prefix = computeMealPhotoKeyPrefix(accountId);
  let cursor: string | undefined;
  do {
    const page = await bucket.list(cursor === undefined ? { prefix } : { prefix, cursor });
    if (page.objects.length > 0) {
      await bucket.delete(page.objects.map(({ key }) => key));
    }
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor !== undefined);
};
