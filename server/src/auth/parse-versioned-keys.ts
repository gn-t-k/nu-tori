// 秘密の値に「版:base64 の鍵」をカンマで並べて置いた鍵を、版から鍵の中身への表にする。
// 鍵を替えるときは末尾に新しい版を足し、いちばん大きい版を今の版にする
export const parseVersionedKeys = (
  secretName: string,
  keys: string,
): {
  currentVersion: number;
  rawKeyOf: (version: number) => Uint8Array<ArrayBuffer>;
  versions: number[];
} => {
  const rawKeys = new Map(
    keys.split(",").map((entry) => {
      const [version, base64] = entry.trim().split(":");
      if (version === undefined || base64 === undefined) {
        throw new Error(`${secretName} は「版:base64 の鍵」をカンマで並べる`);
      }
      return [Number(version), decodeBase64(base64)];
    }),
  );
  const versions = [...rawKeys.keys()];
  return {
    currentVersion: Math.max(...versions),
    rawKeyOf: (version) => {
      const rawKey = rawKeys.get(version);
      if (rawKey === undefined) {
        throw new Error(`${secretName} に版 ${version} の鍵が無い`);
      }
      return rawKey;
    },
    versions,
  };
};

const decodeBase64 = (base64: string): Uint8Array<ArrayBuffer> =>
  Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
