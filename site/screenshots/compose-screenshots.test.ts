import { mkdir, mkdtemp, readdir, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { composeScreenshots } from "./compose-screenshots.ts";
import { readImageSize } from "./testing/read-image-size.ts";
import { readPngSize } from "./testing/read-png-size.ts";
import { writePng } from "./testing/write-png.ts";

describe("合成のコマンド", () => {
  let workDirectory: string;

  // 6.9 インチの生の画面と同じ大きさの単色の画面
  const writeRawScreens = async (names: readonly string[]) => {
    const rawDirectory = path.join(workDirectory, "raw");
    await mkdir(rawDirectory);
    for (const name of names) {
      await writePng({
        filePath: path.join(rawDirectory, `${name}.png`),
        width: 1320,
        height: 2868,
        colorAt: () => [52, 120, 246, 255],
      });
    }
    return rawDirectory;
  };

  // Apple の枠の代わりの、縦横 1:2 の単色の枠。生の画面の大きさの穴が透けている
  const writeSubstituteBezel = async () => {
    const bezelPath = path.join(workDirectory, "bezel.png");
    const holeLeft = 90;
    const holeTop = 66;
    await writePng({
      filePath: bezelPath,
      width: 1500,
      height: 3000,
      colorAt: (x, y) =>
        x >= holeLeft && x < holeLeft + 1320 && y >= holeTop && y < holeTop + 2868
          ? [0, 0, 0, 0]
          : [28, 28, 30, 255],
    });
    return bezelPath;
  };

  beforeEach(async () => {
    workDirectory = await mkdtemp(path.join(tmpdir(), "compose-screenshots-"));
  });

  afterEach(async () => {
    await rm(workDirectory, { recursive: true, force: true });
  });

  describe("LP の手順の絵", () => {
    describe("生の画面が3つそろっているとき", () => {
      let publicDirectory: string;

      beforeEach(async () => {
        const rawDirectory = await writeRawScreens(["step-weigh", "step-photo", "step-guide"]);
        const bezelPath = await writeSubstituteBezel();
        publicDirectory = path.join(workDirectory, "public");
        await composeScreenshots({
          rawDirectory,
          bezelPath,
          publicDirectory,
          stepShotsPath: path.join(workDirectory, "step-shots.json"),
        });
      });

      test("決まった名前の3枚を書き出すこと", async () => {
        const files = await readdir(path.join(publicDirectory, "landing-a", "steps"));
        expect(files.toSorted()).toEqual(["step-guide.webp", "step-photo.webp", "step-weigh.webp"]);
      });

      // 枠の縦横比が 1:2 で、LP の場所取りの幅が 200 なので、LP は 200×400 で置き、絵はその2倍の密度
      test("LP が読む幅と高さを書き、その2倍の密度で書き出すこと", async () => {
        const shots: unknown = JSON.parse(
          await readFile(path.join(workDirectory, "step-shots.json"), "utf8"),
        );
        expect(shots).toEqual({
          "step-weigh": { src: "/landing-a/steps/step-weigh.webp", width: 200, height: 400 },
          "step-photo": { src: "/landing-a/steps/step-photo.webp", width: 200, height: 400 },
          "step-guide": { src: "/landing-a/steps/step-guide.webp", width: 200, height: 400 },
        });
        for (const name of ["step-weigh", "step-photo", "step-guide"]) {
          const size = await readImageSize(
            path.join(publicDirectory, "landing-a", "steps", `${name}.webp`),
          );
          expect(size).toEqual({ width: 400, height: 800, hasAlpha: true });
        }
      });

      describe("同じ入力でもう一度合成したとき", () => {
        let againDirectory: string;

        beforeEach(async () => {
          againDirectory = path.join(workDirectory, "again");
          await composeScreenshots({
            rawDirectory: path.join(workDirectory, "raw"),
            bezelPath: path.join(workDirectory, "bezel.png"),
            publicDirectory: againDirectory,
            stepShotsPath: path.join(againDirectory, "step-shots.json"),
          });
        });

        test("同じ画像を書き出すこと", async () => {
          for (const name of ["step-weigh", "step-photo", "step-guide"]) {
            const relative = path.join("landing-a", "steps", `${name}.webp`);
            const first = await readFile(path.join(publicDirectory, relative));
            const again = await readFile(path.join(againDirectory, relative));
            expect(again.equals(first)).toBe(true);
          }
        });
      });
    });

    describe("生の画面が足りないとき", () => {
      let compose: () => Promise<void>;

      beforeEach(async () => {
        const rawDirectory = await writeRawScreens(["step-weigh"]);
        const bezelPath = await writeSubstituteBezel();
        compose = () =>
          composeScreenshots({
            rawDirectory,
            bezelPath,
            publicDirectory: path.join(workDirectory, "public"),
            stepShotsPath: path.join(workDirectory, "step-shots.json"),
          });
      });

      test("足りない名前を挙げて止まること", async () => {
        await expect(compose()).rejects.toThrow(/step-photo, step-guide/u);
      });
    });
  });

  describe("掲載用のスクリーンショット", () => {
    describe("生の画面が8つそろっているとき", () => {
      let listingDirectory: string;

      beforeEach(async () => {
        const rawDirectory = await writeRawScreens(allRawScreens);
        const bezelPath = await writeSubstituteBezel();
        listingDirectory = path.join(workDirectory, "listing");
        await composeScreenshots({
          rawDirectory,
          bezelPath,
          publicDirectory: path.join(workDirectory, "public"),
          stepShotsPath: path.join(workDirectory, "step-shots.json"),
          listingDirectory,
        });
      });

      test("01 から 05 の5枚を書き出すこと", async () => {
        const files = await readdir(listingDirectory);
        expect(files.toSorted()).toEqual(["01.png", "02.png", "03.png", "04.png", "05.png"]);
      });

      // App Store の iPhone の 6.9 インチの大きさで、アルファのチャンネルを持たない PNG
      test("1320×2868 の透過なしで書き出すこと", async () => {
        for (const name of ["01", "02", "03", "04", "05"]) {
          const size = await readPngSize(path.join(listingDirectory, `${name}.png`));
          expect(size).toEqual({ width: 1320, height: 2868, hasAlpha: false });
        }
      });
    });

    describe("掲載用だけに使う生の画面が足りないとき", () => {
      let compose: () => Promise<void>;

      beforeEach(async () => {
        const rawDirectory = await writeRawScreens(
          allRawScreens.filter((name) => name !== "text-meal" && name !== "weekly-review"),
        );
        const bezelPath = await writeSubstituteBezel();
        compose = () =>
          composeScreenshots({
            rawDirectory,
            bezelPath,
            publicDirectory: path.join(workDirectory, "public"),
            stepShotsPath: path.join(workDirectory, "step-shots.json"),
            listingDirectory: path.join(workDirectory, "listing"),
          });
      });

      test("足りない名前を挙げて止まること", async () => {
        await expect(compose()).rejects.toThrow(/text-meal, weekly-review/u);
      });
    });
  });
});

// 撮る UI テストとの約束の、生の画面の名前の全部（LP の3つと、掲載用だけに使う5つ）
const allRawScreens = [
  "step-weigh",
  "step-photo",
  "step-guide",
  "photo-estimated",
  "text-meal",
  "dish-detail",
  "weekly-review",
  "eat-while-estimating",
];
