import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { chromium, type Browser } from "playwright";
import { appStoreScreenshots, type AppStoreScreenshot } from "../src/app-store-screenshots.ts";
import { encodeWebp } from "./encode-webp.ts";
import { framedScreenHtml } from "./framed-screen-html.ts";
import { loadBezel, type Bezel } from "./load-bezel.ts";

// LP の手順の絵にする生の画面。名前は撮る UI テストとの約束（仕様 #853 の「撮る画面」）
const landingStepScreens = ["step-weigh", "step-photo", "step-guide"] as const;

// LP の場所取り（public/site.css の .lp-shot）の幅。絵はこの2倍の密度で書き出す
const landingStepWidth = 200;
const landingStepScale = 2;

// LP が読む、手順の絵の置き場と幅・高さ（CSS のピクセル）
export type LandingStepShots = Record<
  (typeof landingStepScreens)[number],
  { src: string; width: number; height: number }
>;

// 生の画面のフォルダ（<名前>.png）を受け、Apple の端末の枠に入れた画像を書き出す。
// - LP の手順の絵: publicDirectory/landing-a/steps/<名前>.webp と、その幅・高さを stepShotsPath の JSON に
// - 掲載用のスクリーンショット: listingDirectory/<01〜05>.png に。listingDirectory を渡さなければ書き出さず、その生の画面も求めない
export const composeScreenshots = async ({
  rawDirectory,
  bezelPath,
  publicDirectory,
  stepShotsPath,
  listingDirectory,
}: {
  rawDirectory: string;
  bezelPath: string;
  publicDirectory: string;
  stepShotsPath: string;
  listingDirectory?: string | undefined;
}): Promise<void> => {
  const requiredScreens = new Set<string>(landingStepScreens);
  if (listingDirectory !== undefined) {
    for (const { screens } of appStoreScreenshots) {
      for (const name of screens) requiredScreens.add(name);
    }
  }
  const missing: string[] = [];
  for (const name of requiredScreens) {
    if (!(await exists(path.join(rawDirectory, `${name}.png`)))) {
      missing.push(name);
    }
  }
  if (missing.length > 0) {
    throw new Error(
      `生の画面が足りない: ${missing.join(", ")}（${rawDirectory} に <名前>.png で置く）`,
    );
  }

  const browser = await chromium.launch();
  try {
    const bezel = await loadBezel(await browser.newPage(), bezelPath);
    const height = Math.round((landingStepWidth * bezel.height) / bezel.width);
    const stepsDirectory = path.join(publicDirectory, "landing-a", "steps");
    await mkdir(stepsDirectory, { recursive: true });
    const shots: Partial<LandingStepShots> = {};
    for (const name of landingStepScreens) {
      const png = await renderFramedScreen({
        browser,
        bezel,
        screenPath: path.join(rawDirectory, `${name}.png`),
        width: landingStepWidth,
        height,
      });
      const webp = await encodeWebp(await browser.newPage(), png);
      await writeFile(path.join(stepsDirectory, `${name}.webp`), webp);
      shots[name] = { src: `/landing-a/steps/${name}.webp`, width: landingStepWidth, height };
    }
    await mkdir(path.dirname(stepShotsPath), { recursive: true });
    await writeFile(stepShotsPath, `${JSON.stringify(shots, undefined, 2)}\n`);

    if (listingDirectory !== undefined) {
      await mkdir(listingDirectory, { recursive: true });
      for (const screenshot of appStoreScreenshots) {
        const png = await renderListingScreenshot({ browser, bezel, rawDirectory, screenshot });
        await writeFile(path.join(listingDirectory, `${screenshot.name}.png`), png);
      }
    }
  } finally {
    await browser.close();
  }
};

// 枠に入れた画面を、地を透過にした PNG にする。字とトークンは LP と同じ public/site.css を読む
const renderFramedScreen = async ({
  browser,
  bezel,
  screenPath,
  width,
  height,
}: {
  browser: Browser;
  bezel: Bezel;
  screenPath: string;
  width: number;
  height: number;
}): Promise<Buffer> => {
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: landingStepScale,
    colorScheme: "light",
  });
  try {
    // 決まった入力から同じ画像になるよう、外のものを読み込まない（画像は data: の URL で渡す）
    await context.route("**/*", (route) => route.abort());
    const page = await context.newPage();
    const screenDataUrl = `data:image/png;base64,${(await readFile(screenPath)).toString("base64")}`;
    await page.setContent(
      [
        "<!doctype html>",
        `<style>${await readFile(siteCssPath, "utf8")}</style>`,
        "<style>html, body { margin: 0; background: transparent; }</style>",
        framedScreenHtml(bezel, screenDataUrl),
      ].join(""),
    );
    return await page.screenshot({ type: "png", omitBackground: true });
  } finally {
    await context.close();
  }
};

// 掲載用の1枚を、地の色と見出しと、枠に入れた生の画面を並べた PNG にする。地を塗るので、PNG はアルファのチャンネルを持たない（App Store が透過を受け付けないため）
const renderListingScreenshot = async ({
  browser,
  bezel,
  rawDirectory,
  screenshot,
}: {
  browser: Browser;
  bezel: Bezel;
  rawDirectory: string;
  screenshot: AppStoreScreenshot;
}): Promise<Buffer> => {
  // App Store の iPhone の 6.9 インチの大きさ
  const width = 1320;
  const height = 2868;
  const headlineHeight = 640;
  const gap = 48;
  const margin = 80;
  const count = screenshot.screens.length;
  // 枠は画面の幅と、見出しの下の高さの両方に収まる大きさにする。Apple の決まりで、端末は切らずに全体を見せる
  const deviceWidth = Math.floor(
    Math.min(
      (width - margin * 2 - gap * (count - 1)) / count,
      ((height - headlineHeight - margin) * bezel.width) / bezel.height,
      1000,
    ),
  );
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: 1,
    colorScheme: "light",
  });
  try {
    await context.route("**/*", (route) => route.abort());
    const page = await context.newPage();
    const devices: string[] = [];
    for (const name of screenshot.screens) {
      const screenDataUrl = `data:image/png;base64,${(await readFile(path.join(rawDirectory, `${name}.png`))).toString("base64")}`;
      devices.push(
        `<div style="width: ${deviceWidth}px; flex: none">${framedScreenHtml(bezel, screenDataUrl)}</div>`,
      );
    }
    // 見出しの字の大きさは DESIGN.md の typography に無い。App Store の検索の結果に縮んで出ても読めるよう、画像の幅に合わせて大きくする
    const headlineStyle = [
      `height: ${headlineHeight}px`,
      "box-sizing: border-box",
      `padding: 0 ${margin}px`,
      "display: flex",
      "align-items: center",
      "justify-content: center",
      "margin: 0",
      "font-size: 88px",
      "font-weight: 700",
      "line-height: 1.35",
      "text-align: center",
      "word-break: auto-phrase",
      "text-wrap: balance",
      "color: var(--on-surface)",
    ].join("; ");
    await page.setContent(
      [
        "<!doctype html>",
        `<style>${await readFile(siteCssPath, "utf8")}</style>`,
        `<style>html, body { margin: 0; width: ${width}px; height: ${height}px; overflow: hidden; background: var(--background); }</style>`,
        `<h1 style="${headlineStyle}">${escapeHtml(screenshot.headline.text)}</h1>`,
        `<div style="height: ${height - headlineHeight - margin}px; display: flex; align-items: center; justify-content: center; gap: ${gap}px">${devices.join("")}</div>`,
      ].join(""),
    );
    return await page.screenshot({ type: "png" });
  } finally {
    await context.close();
  }
};

const escapeHtml = (text: string) =>
  text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

const siteCssPath = path.join(import.meta.dirname, "..", "public", "site.css");

const exists = async (filePath: string) =>
  access(filePath).then(
    () => true,
    () => false,
  );
