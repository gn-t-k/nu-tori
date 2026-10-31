import { readFile } from "node:fs/promises";

// 書き出した WebP の幅・高さと透過の有無を、ファイルの頭から読む（https://developers.google.com/speed/webp/docs/riff_container）
export const readImageSize = async (
  filePath: string,
): Promise<{ width: number; height: number; hasAlpha: boolean }> => {
  const bytes = await readFile(filePath);
  if (bytes.toString("ascii", 0, 4) !== "RIFF" || bytes.toString("ascii", 8, 12) !== "WEBP") {
    throw new Error(`${filePath} is not WebP`);
  }
  const chunkType = bytes.toString("ascii", 12, 16);
  if (chunkType === "VP8X") {
    return {
      width: bytes.readUIntLE(24, 3) + 1,
      height: bytes.readUIntLE(27, 3) + 1,
      hasAlpha: (bytes.readUInt8(20) & 0x10) !== 0,
    };
  }
  if (chunkType === "VP8L") {
    const bits = bytes.readUInt32LE(21);
    return {
      width: (bits & 0x3fff) + 1,
      height: ((bits >> 14) & 0x3fff) + 1,
      hasAlpha: ((bits >> 28) & 1) !== 0,
    };
  }
  if (chunkType === "VP8 ") {
    return {
      width: bytes.readUInt16LE(26) & 0x3fff,
      height: bytes.readUInt16LE(28) & 0x3fff,
      hasAlpha: false,
    };
  }
  throw new Error(`${filePath} has an unknown WebP chunk ${chunkType}`);
};
