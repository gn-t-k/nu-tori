// 食事より先に届いた写真の控えを、食事が届かないまま持っておく期限。
// 写真と食事の書き込みは同じ電波で送るので、ふつうは間をおかずに食事が届く。端末は届いた縮小版を消すので、期限のあとに食事が届くと写真を待ったままになる。それが起きない長さにする
export const computeUndeclaredMealPhotoExpiryAt = (receivedAt: Date): Date => {
  const keptDays = 30;
  return new Date(receivedAt.getTime() + keptDays * 24 * 60 * 60 * 1000);
};
