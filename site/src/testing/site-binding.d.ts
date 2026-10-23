// テストの実行環境だけがつなぐ（vitest.config.ts）。出すときと同じく、assets の振り分けの前段から通す Worker
declare namespace Cloudflare {
  interface Env {
    SITE: Fetcher;
    SITE_WITH_LANDING_VARIANTS: Fetcher;
  }
}
