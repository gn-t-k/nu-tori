import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { unstable_getMiniflareWorkerOptions } from "wrangler";
import { defineConfig } from "vitest/config";

// テストの実行環境の main の Worker（SELF）は、assets の振り分けの前段（run_worker_first）を通らない。
// 出すときと同じ形で確かめるため、wrangler.jsonc の設定のまま、wrangler が束ねた Worker と vite build で書き出した dist を別の Worker として動かし、SITE でつなぐ。
// 束ねと書き出しは scripts/check site がテストの前に回す
const {
  // 束ねたあとの1つの JS を渡すので、wrangler の束ねの決まりは要らない（miniflare の v5 が受け付けない）
  workerOptions: { modulesRules: _modulesRules, ...siteWorkerOptions },
} = unstable_getMiniflareWorkerOptions("./wrangler.jsonc");

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: {
        serviceBindings: { SITE: "nu-tori-site-test" },
        workers: [
          {
            ...siteWorkerOptions,
            name: "nu-tori-site-test",
            modules: true,
            scriptPath: "./.wrangler/test-worker/worker.js",
          },
        ],
      },
    }),
  ],
  test: {
    restoreMocks: true,
  },
});
