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

// 本番の LP_VARIANTS は LP を出すまで空なので、版の振り分けは、版を2つにした Worker で確かめる。
// 2つめの版 b はテストだけの版で、vite build --mode test が本番のページに足して .wrangler/test-dist に書き出す（src/testing/test-site-app.tsx）。
// 乱数は Worker の中の Math.random を vi.spyOn で差し替えられないので、版を選ぶ値（LP_VARIANT_DRAW）を b を引く値に決める
const {
  workerOptions: { modulesRules: _variantsModulesRules, ...siteWithLandingVariantsOptions },
} = unstable_getMiniflareWorkerOptions("./wrangler.jsonc", undefined, {
  overrides: { assets: { directory: "./.wrangler/test-dist" } },
});

export default defineConfig({
  plugins: [
    cloudflareTest({
      wrangler: { configPath: "./wrangler.jsonc" },
      miniflare: {
        serviceBindings: {
          SITE: "nu-tori-site-test",
          SITE_WITH_LANDING_VARIANTS: "nu-tori-site-with-landing-variants-test",
        },
        workers: [
          {
            ...siteWorkerOptions,
            name: "nu-tori-site-test",
            modules: true,
            scriptPath: "./.wrangler/test-worker/worker.js",
          },
          {
            ...siteWithLandingVariantsOptions,
            name: "nu-tori-site-with-landing-variants-test",
            modules: true,
            scriptPath: "./.wrangler/test-worker/worker.js",
            // wrangler.jsonc の vars は LP_VARIANTS だけなので、置き換える。vars を足したら、ここにも足す
            bindings: { LP_VARIANTS: ["a", "b"], LP_VARIANT_DRAW: 0.99 },
          },
        ],
      },
    }),
  ],
  test: {
    restoreMocks: true,
  },
});
