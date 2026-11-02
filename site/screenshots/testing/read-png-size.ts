import { readFile } from "node:fs/promises";

// 書き出した PNG の幅・高さとアルファの有無を、ファイルの頭とチャンクの並びから読む（https://www.w3.org/TR/png-3/）
export const readPngSize = async (
  filePath: string,
): Promise<{ width: number; height: number; hasAlpha: boolean }> => {
  const bytes = await readFile(filePath);
  if (!bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    throw new Error(`${filePath} is not PNG`);
  }
  // 色の型の 4（グレーとアルファ）と 6（RGBA）はアルファのチャンネルを持つ。tRNS のチャンクがあれば、ほかの型でも透ける色を持つ
  const colorType = bytes.readUInt8(25);
  return {
    width: bytes.readUInt32BE(16),
    height: bytes.readUInt32BE(20),
    hasAlpha: colorType === 4 || colorType === 6 || chunkTypes(bytes).includes("tRNS"),
  };
};

const chunkTypes = (bytes: Buffer): string[] => {
  const types: string[] = [];
  let offset = 8;
  while (offset + 8 <= bytes.length) {
    const length = bytes.readUInt32BE(offset);
    types.push(bytes.toString("ascii", offset + 4, offset + 8));
    // 長さ、型、中身、CRC の順
    offset += 12 + length;
  }
  return types;
};
