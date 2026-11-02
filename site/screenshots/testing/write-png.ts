import { writeFile } from "node:fs/promises";
import { crc32, deflateSync } from "node:zlib";

type Rgba = readonly [red: number, green: number, blue: number, alpha: number];

// テストの作り物の画像（単色の生の画面、穴の空いた単色の枠）を、依存を足さずに PNG で書く
export const writePng = async ({
  filePath,
  width,
  height,
  colorAt,
}: {
  filePath: string;
  width: number;
  height: number;
  colorAt: (x: number, y: number) => Rgba;
}): Promise<void> => {
  // 各行の頭に、フィルターなしを表す 0 を置く
  const rowLength = 1 + width * 4;
  const pixels = Buffer.alloc(rowLength * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      pixels.set(colorAt(x, y), y * rowLength + 1 + x * 4);
    }
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  // 8 ビットの RGBA、圧縮・フィルター・インターレースは既定
  header.set([8, 6, 0, 0, 0], 8);
  await writeFile(
    filePath,
    Buffer.concat([
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      chunk("IHDR", header),
      chunk("IDAT", deflateSync(pixels)),
      chunk("IEND", Buffer.alloc(0)),
    ]),
  );
};

const chunk = (type: string, data: Buffer): Buffer => {
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const typeAndData = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(typeAndData));
  return Buffer.concat([length, typeAndData, checksum]);
};
