// 掲載用のスクリーンショットを medium の大きさに縮める入口。site/ で `node screenshots/scale-listing-screenshots-command.ts` と回す（site/AGENTS.md「合成する」）
// 枠を使わないので、枠の無いクラウドのセッションでも回せる
import {
  listingScreenshotDirectory,
  mediumListingScreenshotDirectory,
} from "./listing-screenshot-directory.ts";
import { scaleListingScreenshots } from "./scale-listing-screenshots.ts";

await scaleListingScreenshots({
  listingDirectory: listingScreenshotDirectory,
  mediumDirectory: mediumListingScreenshotDirectory,
});
