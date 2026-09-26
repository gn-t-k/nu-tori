import { cloudflareTest } from "@cloudflare/vitest-pool-workers";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [
    // Workers AI のつなぎは手元の実行環境が無く、既定では Cloudflare のアカウントにつなぎに行く。テストは手元で閉じる
    cloudflareTest({ wrangler: { configPath: "./wrangler.jsonc" }, remoteBindings: false }),
  ],
  test: {
    restoreMocks: true,
  },
});
