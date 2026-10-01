// JPEG の先頭の印から始まり、写真ごとに中身が違うもの
export const createPhotoBytes = (size = 64): Uint8Array => {
  const bytes = crypto.getRandomValues(new Uint8Array(size));
  bytes.set([0xff, 0xd8, 0xff]);
  return bytes;
};
