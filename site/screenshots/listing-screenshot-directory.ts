import path from "node:path";

// 掲載用のスクリーンショットの置き場。見出しを持つ掲載情報のモジュール（src/app-store-screenshots.ts）のそばに置き、wizard がここから上げる
export const listingScreenshotDirectory = path.join(
  import.meta.dirname,
  "..",
  "src",
  "app-store-screenshot-images",
);

// App Store Connect に上げる medium の大きさの置き場
export const mediumListingScreenshotDirectory = path.join(listingScreenshotDirectory, "medium");
