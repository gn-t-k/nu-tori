// 掲載用のスクリーンショットを medium の大きさに縮める入口。site/ で `node screenshots/scale-listing-screenshots-command.ts` と回す（site/AGENTS.md「合成する」）
// 枠を使わないので、枠の無いクラウドのセッションでも回せる
import path from "node:path";
import { scaleListingScreenshots } from "./scale-listing-screenshots.ts";

const siteDirectory = path.join(import.meta.dirname, "..");

await scaleListingScreenshots({
  listingDirectory: path.join(siteDirectory, "src", "app-store-screenshot-images"),
  mediumDirectory: path.join(siteDirectory, "src", "app-store-screenshot-images", "medium"),
});
