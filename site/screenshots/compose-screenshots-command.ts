// 合成のコマンドの入口。site/ で `node screenshots/compose-screenshots-command.ts <生の画面のフォルダ> [--bezel <枠の PNG>]` と回す（site/AGENTS.md「合成する」）
import { access } from "node:fs/promises";
import path from "node:path";
import { parseArgs } from "node:util";
import { composeScreenshots } from "./compose-screenshots.ts";

const siteDirectory = path.join(import.meta.dirname, "..");

// Apple の枠は使用許諾で配り直せないので、リポジトリに置かず、開発者が .gitignore した置き場に置く（site/AGENTS.md「合成する」）
const defaultBezelPath = path.join(siteDirectory, "screenshots", "bezel", "iphone.png");

const {
  positionals: [rawDirectory],
  values: { bezel: bezelPath = defaultBezelPath },
} = parseArgs({ allowPositionals: true, options: { bezel: { type: "string" } } });

if (rawDirectory === undefined) {
  throw new Error(
    "生の画面のフォルダを渡す: node screenshots/compose-screenshots-command.ts <フォルダ> [--bezel <枠の PNG>]",
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
});
