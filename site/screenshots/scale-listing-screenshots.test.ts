import { mkdir, mkdtemp, readdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, test } from "vitest";
import { scaleListingScreenshots } from "./scale-listing-screenshots.ts";
import { readPngSize } from "./testing/read-png-size.ts";
import { writePng } from "./testing/write-png.ts";

describe("掲載用のスクリーンショットを medium に縮めるコマンド", () => {
  let workDirectory: string;
  let listingDirectory: string;
  let mediumDirectory: string;

  // 6.9 インチの掲載用の1枚と同じ大きさの、透過なしの単色の画像
  const writeListingScreenshots = async (names: readonly string[]) => {
    await mkdir(listingDirectory);
    for (const name of names) {
      await writePng({
        filePath: path.join(listingDirectory, `${name}.png`),
        width: 1320,
        height: 2868,
        colorAt: () => [33, 82, 196, 255],
      });
    }
  };

  beforeEach(async () => {
    workDirectory = await mkdtemp(path.join(tmpdir(), "scale-listing-screenshots-"));
    listingDirectory = path.join(workDirectory, "listing");
    mediumDirectory = path.join(workDirectory, "medium");
  });

  afterEach(async () => {
    await rm(workDirectory, { recursive: true, force: true });
  });

  describe("掲載用の5枚がそろっているとき", () => {
    beforeEach(async () => {
      await writeListingScreenshots(["01", "02", "03", "04", "05"]);
      await scaleListingScreenshots({ listingDirectory, mediumDirectory });
    });

    test("01 から 05 の5枚を書き出すこと", async () => {
      const files = await readdir(mediumDirectory);
      expect(files.toSorted()).toEqual(["01.png", "02.png", "03.png", "04.png", "05.png"]);
    });

    // App Store Connect の iPhone の medium（6.3 インチ）の大きさで、アルファのチャンネルを持たない PNG
    test("1206×2622 の透過なしで書き出すこと", async () => {
      for (const name of ["01", "02", "03", "04", "05"]) {
        const size = await readPngSize(path.join(mediumDirectory, `${name}.png`));
        expect(size).toEqual({ width: 1206, height: 2622, hasAlpha: false });
      }
    });
  });

  describe("掲載用の画像が足りないとき", () => {
    beforeEach(async () => {
      await writeListingScreenshots(["01", "02", "03"]);
    });

    test("足りない名前を挙げて止まること", async () => {
      await expect(scaleListingScreenshots({ listingDirectory, mediumDirectory })).rejects.toThrow(
        /04, 05/u,
      );
    });
  });
});
