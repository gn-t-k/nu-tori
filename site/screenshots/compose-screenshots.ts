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
    for (const { screen } of appStoreScreenshots) requiredScreens.add(screen);
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

// 掲載用の1枚を、primary の地に白の見出しを置き、その下に枠に入れた生の画面を1台置いた PNG にする（#867 の解決コメントの1、試作 prototype/867-listing-screenshots の案A）。
// 地を塗るので、PNG はアルファのチャンネルを持たない（App Store が透過を受け付けないため）
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
  // 端末はキャンバスの高さの約75%で、下に寄せる。枠は切らずに全体を見せる（Apple の決まり）
  const deviceHeight = 2180;
  const deviceBottom = 110;
  const deviceWidth = (deviceHeight * bezel.width) / bezel.height;
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: 1,
    colorScheme: "light",
  });
  try {
    await context.route("**/*", (route) => route.abort());
    const page = await context.newPage();
    const screenDataUrl = `data:image/png;base64,${(await readFile(path.join(rawDirectory, `${screenshot.screen}.png`))).toString("base64")}`;
    // 見出しの字の大きさと要の語の色は DESIGN.md の typography と colors に無い。App Store の検索の結果に縮んで出ても読めるよう大きくする。
    // 要の語は primary の地で目立つ黄色にする（#867 の試作の案A で開発者と決めた値）。白は DESIGN.md の on-primary
    const headlineStyle = [
      "position: absolute",
      "left: 90px",
      "right: 90px",
      "top: 170px",
      "margin: 0",
      "font-size: 112px",
      "font-weight: 800",
      "line-height: 1.3",
      "letter-spacing: 0.01em",
      "text-align: center",
      "word-break: auto-phrase",
      "text-wrap: balance",
      "color: #ffffff",
    ].join("; ");
    const deviceStyle = [
      "position: absolute",
      `left: ${(width - deviceWidth) / 2}px`,
      `bottom: ${deviceBottom}px`,
      `width: ${deviceWidth}px`,
    ].join("; ");
    await page.setContent(
      [
        "<!doctype html>",
        `<style>${await readFile(siteCssPath, "utf8")}</style>`,
        `<style>html, body { margin: 0; width: ${width}px; height: ${height}px; overflow: hidden; position: relative; background: var(--primary); }</style>`,
        `<h1 lang="ja" style="${headlineStyle}">${headlineHtml(screenshot)}</h1>`,
        `<div style="${deviceStyle}">${framedScreenHtml(bezel, screenDataUrl)}</div>`,
      ].join(""),
    );
    // 見出しは2行まで（#867 の解決コメントの1）。112px で3行になる文は、2行に収まるまで字を小さくする。端末に重ならないよう、収まらなければ止まる
    const fits = await page.evaluate(
      ({ sizes, lineHeight }) => {
        const headline = document.querySelector("h1");
        if (headline === null) return false;
        for (const size of sizes) {
          headline.style.fontSize = `${size}px`;
          if (headline.getBoundingClientRect().height <= size * lineHeight * 2 + 1) return true;
        }
        return false;
      },
      { sizes: [112, 108, 104, 100, 96], lineHeight: 1.3 },
    );
    if (!fits) {
      throw new Error(`見出しが2行に収まらない: ${screenshot.name}（${screenshot.headline.text}）`);
    }
    return await page.screenshot({ type: "png" });
  } finally {
    await context.close();
  }
};

// 見出しの文の、要の語の最初の1か所だけを色を変えた span で包む
const headlineHtml = ({ headline, emphasis }: AppStoreScreenshot) => {
  const at = headline.text.indexOf(emphasis);
  if (emphasis === "" || at === -1) {
    throw new Error(`見出しに要の語が無い: 「${emphasis}」（${headline.text}）`);
  }
  return [
    escapeHtml(headline.text.slice(0, at)),
    `<span style="color: #ffe27a; white-space: nowrap">${escapeHtml(emphasis)}</span>`,
    escapeHtml(headline.text.slice(at + emphasis.length)),
  ].join("");
};

const escapeHtml = (text: string) =>
  text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;");

const siteCssPath = path.join(import.meta.dirname, "..", "public", "site.css");

const exists = async (filePath: string) =>
  access(filePath).then(
    () => true,
    () => false,
  );
