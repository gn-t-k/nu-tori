import type { Page } from "playwright";

// Playwright の画面の書き出しは PNG と JPEG だけなので、透過を残せる WebP には Chromium の canvas で変える
export const encodeWebp = async (page: Page, png: Buffer): Promise<Buffer> => {
  const base64 = await page.evaluate(
    async (source) => {
      const image = new Image();
      image.src = source;
      await image.decode();
      const canvas = document.createElement("canvas");
      canvas.width = image.naturalWidth;
      canvas.height = image.naturalHeight;
      const context = canvas.getContext("2d");
      if (context === null) {
        throw new Error("canvas の 2d が使えない");
      }
      context.drawImage(image, 0, 0);
      // 劣化のある圧縮で軽くする。同じ入力からは同じバイト列になる
      return canvas.toDataURL("image/webp", 0.9).replace(/^data:image\/webp;base64,/u, "");
    },
    `data:image/png;base64,${png.toString("base64")}`,
  );
  return Buffer.from(base64, "base64");
};
