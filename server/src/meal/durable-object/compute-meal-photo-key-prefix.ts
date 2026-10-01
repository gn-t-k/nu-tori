// R2 の写真の控えのキーは `<アカウント ID>/meal-photos/<写真の ID>`。キーを表に持たず、アカウントの削除では、この接頭辞で一覧して消す
export const computeMealPhotoKeyPrefix = (accountId: string): string => `${accountId}/meal-photos/`;
