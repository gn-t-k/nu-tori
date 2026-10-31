// 合成のコマンドの入口。site/ で `node screenshots/compose-screenshots-command.ts <生の画面のフォルダ> [--bezel <枠の PNG>] [--landing-only]` と回す（site/AGENTS.md「合成する」）
// --landing-only は LP の手順の絵だけを書き出す。掲載用の生の画面がまだ撮れないうちに LP の絵を作るため
import { access } from "node:fs/promises";
import path from "node:path";
import { parseArgs } from "node:util";
import { composeScreenshots } from "./compose-screenshots.ts";

const siteDirectory = path.join(import.meta.dirname, "..");

// Apple の枠は使用許諾で配り直せないので、リポジトリに置かず、開発者が .gitignore した置き場に置く（site/AGENTS.md「合成する」）
const defaultBezelPath = path.join(siteDirectory, "screenshots", "bezel", "iphone.png");

const {
  positionals: [rawDirectory],
  values: { bezel: bezelPath = defaultBezelPath, "landing-only": landingOnly = false },
} = parseArgs({
  allowPositionals: true,
  options: { bezel: { type: "string" }, "landing-only": { type: "boolean" } },
});

if (rawDirectory === undefined) {
  throw new Error(
    "生の画面のフォルダを渡す: node screenshots/compose-screenshots-command.ts <フォルダ> [--bezel <枠の PNG>] [--landing-only]",
  );
}
await access(bezelPath).catch(() => {
  throw new Error(
    `端末の枠が無い: ${bezelPath}。Apple Design Resources の iPhone の枠の PNG を置く（site/AGENTS.md「合成する」）`,
  );
});

await composeScreenshots({
  rawDirectory: path.resolve(rawDirectory),
  bezelPath: path.resolve(bezelPath),
  publicDirectory: path.join(siteDirectory, "public"),
  stepShotsPath: path.join(siteDirectory, "src", "pages", "landing-a", "step-shots.json"),
  // 掲載用の5枚は、見出しを持つ掲載情報のモジュール（src/app-store-screenshots.ts）のそばに置き、wizard がここから上げる
  listingDirectory: landingOnly
    ? undefined
    : path.join(siteDirectory, "src", "app-store-screenshot-images"),
});
