import { readFile } from "node:fs/promises";
import type { Page } from "playwright";

// 端末の枠の画像と、その中で画面が透けている穴の位置。数はすべて枠の画像のピクセル
export type Bezel = {
  dataUrl: string;
  width: number;
  height: number;
  screen: { left: number; top: number; width: number; height: number; cornerRadius: number };
};

// Apple Design Resources の iPhone の枠（PNG）は、画面の所が透けている。枠ごとに穴の位置を書かずに済むよう、穴を画像から読む
export const loadBezel = async (page: Page, bezelPath: string): Promise<Bezel> => {
  const dataUrl = `data:image/png;base64,${(await readFile(bezelPath)).toString("base64")}`;
  const measured = await page.evaluate(async (source) => {
    const image = new Image();
    image.src = source;
    await image.decode();
    const { naturalWidth: width, naturalHeight: height } = image;
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d");
    if (context === null) {
      throw new Error("canvas の 2d が使えない");
    }
    context.drawImage(image, 0, 0);
    const { data } = context.getImageData(0, 0, width, height);
    const isClear = (x: number, y: number) => data[(y * width + x) * 4 + 3] === 0;
    const centerX = Math.floor(width / 2);
    const centerY = Math.floor(height / 2);
    if (!isClear(centerX, centerY)) {
      return undefined;
    }
    let left = centerX;
    while (left > 0 && isClear(left - 1, centerY)) left--;
    let right = centerX;
    while (right < width - 1 && isClear(right + 1, centerY)) right++;
    // 真ん中の縦の線は、上の端で Dynamic Island に当たることがあるので、穴の左から4分の1の所で上下の端を探す
    const probeX = Math.floor(left + (right - left) / 4);
    let top = centerY;
    while (top > 0 && isClear(probeX, top - 1)) top--;
    let bottom = centerY;
    while (bottom < height - 1 && isClear(probeX, bottom + 1)) bottom++;
    // 穴の左上の角から斜めに進み、透ける所までの長さから角の丸みの半径を出す（円の角では、その長さは各軸で r(1 - 1/√2)）
    let diagonal = 0;
    while (diagonal < (right - left) / 2 && !isClear(left + diagonal, top + diagonal)) diagonal++;
    return {
      width,
      height,
      screen: {
        left,
        top,
        width: right - left + 1,
        height: bottom - top + 1,
        cornerRadius: diagonal / (1 - Math.SQRT1_2),
      },
    };
  }, dataUrl);
  if (measured === undefined) {
    throw new Error(
      `端末の枠の真ん中が透けていない。画面の所が透けた枠の PNG を渡す: ${bezelPath}`,
    );
  }
  return { dataUrl, ...measured };
};
