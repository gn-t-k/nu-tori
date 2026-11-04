import { mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright";
import { appStoreScreenshots } from "../src/app-store-screenshots.ts";
import { exists } from "./exists.ts";
import { pngDataUrl } from "./png-data-url.ts";
import { withIsolatedPage } from "./with-isolated-page.ts";

// App Store Connect の iPhone の欄が受け付ける medium（6.3 インチ）の大きさ。6.9 インチの 1320×2868 だけでは上げられなかった（#863）
const mediumWidth = 1206;
const mediumHeight = 2622;

// 6.9 インチと縦横の比がほぼ同じ（縮めた高さの差は2ピクセルに満たない）なので、撮り直しも枠も使わずに縮めるだけにする
export const scaleListingScreenshots = async ({
  listingDirectory,
  mediumDirectory,
}: {
  listingDirectory: string;
  mediumDirectory: string;
}): Promise<void> => {
  const missing: string[] = [];
  for (const { name } of appStoreScreenshots) {
    if (!(await exists(path.join(listingDirectory, `${name}.png`)))) missing.push(name);
  }
  if (missing.length > 0) {
    throw new Error(
      `掲載用のスクリーンショットが足りない: ${missing.join(", ")}（${listingDirectory}）`,
    );
  }

  await mkdir(mediumDirectory, { recursive: true });
  const browser = await chromium.launch();
  try {
    await withIsolatedPage(
      { browser, width: mediumWidth, height: mediumHeight, deviceScaleFactor: 1 },
      async (page) => {
        for (const { name } of appStoreScreenshots) {
          const source = pngDataUrl(await readFile(path.join(listingDirectory, `${name}.png`)));
          // 地を不透明の色で塗り、omitBackground を使わないので、PNG はアルファのチャンネルを持たない（App Store が透過を受け付けないため）
          await page.setContent(
            [
              "<!doctype html>",
              "<style>html, body { margin: 0; background: #000; } img { display: block; }</style>",
              `<img src="${source}" width="${mediumWidth}" height="${mediumHeight}" alt="">`,
            ].join(""),
          );
          await page.locator("img").evaluate((image: HTMLImageElement) => image.decode());
          await writeFile(
            path.join(mediumDirectory, `${name}.png`),
            await page.screenshot({ type: "png" }),
          );
        }
      },
    );
  } finally {
    await browser.close();
  }
};
