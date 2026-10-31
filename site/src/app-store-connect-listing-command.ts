// wizard が掲載情報を読む入口。site/ で `node src/app-store-connect-listing-command.ts <drafts | json>` と回す（site/AGENTS.md「掲載情報を直す」）
// - drafts: 仮の文が残っている欄を1行に1つ書き、残っていれば 1 で終わる
// - json: 掲載情報を JSON で書く
// 掲載情報は site/ のページの一覧から URL を作り、ページは Node のまま読めない .tsx なので、Vite の runnerImport で読む
import path from "node:path";
import { argv, exit, stdout } from "node:process";
import { runnerImport } from "vite";

const {
  module: { appStoreConnectListing, draftListingFields },
} = await runnerImport<typeof import("./app-store-connect-listing.ts")>(
  path.join(import.meta.dirname, "app-store-connect-listing.ts"),
  { configFile: false, logLevel: "silent" },
);

const subcommand = argv[2];
if (subcommand === "drafts") {
  const fields = draftListingFields(appStoreConnectListing);
  stdout.write(fields.map((field) => `${field}\n`).join(""));
  exit(fields.length > 0 ? 1 : 0);
} else if (subcommand === "json") {
  stdout.write(`${JSON.stringify(appStoreConnectListing, undefined, 2)}\n`);
} else {
  throw new Error(
    "drafts か json を渡す: node src/app-store-connect-listing-command.ts <drafts | json>",
  );
}
