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

// テストの書き出し（.wrangler/test-dist）を配る設定。vite build --mode test が、本番のページにテストだけの LP の版 b を足し、考え方のページを隠すのを外した形に置き換えて書き出す（src/testing/test-site-app.tsx）
const {
  workerOptions: { modulesRules: _testDistModulesRules, ...testDistWorkerOptions },
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
          SITE_WITHOUT_LANDING_VARIANTS: "nu-tori-site-without-landing-variants-test",
          SITE_WITH_LEARN_PAGES_LISTED: "nu-tori-site-with-learn-pages-listed-test",
        },
        workers: [
          {
            ...siteWorkerOptions,
            name: "nu-tori-site-test",
            modules: true,
            scriptPath: "./.wrangler/test-worker/worker.js",
          },
          // 本番の LP_VARIANTS は版 a だけなので、版の振り分けは、テストの書き出しの版 b を足して版を2つにした Worker で確かめる。
          // Worker は、版を選ぶ乱数を b を引く値に決めたテストだけの入口（src/testing/landing-variants-test-worker.ts）を束ねたもの
          {
            ...testDistWorkerOptions,
            name: "nu-tori-site-with-landing-variants-test",
            modules: true,
            scriptPath: "./.wrangler/test-landing-variants-worker/landing-variants-test-worker.js",
            // wrangler.jsonc の vars は LP_VARIANTS だけなので、置き換える。vars を足したら、ここにも足す
            bindings: { LP_VARIANTS: ["a", "b"] },
          },
          // 版を全部外したときの仮のページは、本番の LP_VARIANTS では通らないので、版を空にした Worker で確かめる
          {
            ...siteWorkerOptions,
            name: "nu-tori-site-without-landing-variants-test",
            modules: true,
            scriptPath: "./.wrangler/test-worker/worker.js",
            // wrangler.jsonc の vars は LP_VARIANTS だけなので、置き換える。vars を足したら、ここにも足す
            bindings: { LP_VARIANTS: [] },
          },
          // 考え方のページは、並びが6本にそろうまで隠す。そろったあとの形は、テストの書き出しを本番の Worker で配って確かめる
          {
            ...testDistWorkerOptions,
            name: "nu-tori-site-with-learn-pages-listed-test",
            modules: true,
            scriptPath: "./.wrangler/test-worker/worker.js",
          },
        ],
      },
    }),
  ],
  test: {
    // 合成のコマンドのテスト（screenshots/）は Node で回す（vitest.screenshots.config.ts）
    include: ["src/**/*.test.ts"],
    restoreMocks: true,
  },
});
