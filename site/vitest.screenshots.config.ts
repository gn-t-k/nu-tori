import { defineConfig } from "vitest/config";

// 合成のコマンド（screenshots/）は Node で Playwright の Chromium を動かすので、Worker の実行環境の vitest.config.ts と分けて、Node の vitest で回す
export default defineConfig({
  test: {
    include: ["screenshots/**/*.test.ts"],
    restoreMocks: true,
    // Chromium を立ち上げて画像を書き出すので、既定の 5 秒では足りない
    testTimeout: 60_000,
    hookTimeout: 60_000,
  },
});
