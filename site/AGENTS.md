# site

`nu-tori.app` のページ。`hono/jsx` で書いたページを `vite build` と `@hono/vite-ssg` で静的な HTML に書き出し（`src/site-app.tsx`）、`/` と `/_lp/*` だけを振り分けの Worker（`src/worker.ts`）に通す。ほかのパスは Worker を通らず、静的な asset のまま返る。書く・直すときは `docs/agents/privacy.md` も読む。

## ページを足す

1. `src/pages/<名前>-page.tsx` に `SitePage`（`src/site-page.ts`）を1つ書く。`outputPath` は末尾のスラッシュ無し（`/terms` → `terms.html`）にし、検索に載せるページは `search` を `indexed` にして、正規の URL のパスを `outputPath` と同じにする
2. ページの一覧（`src/site-pages.ts`）に足す。書き出し・`sitemap.xml`・`<head>`・テストがここを読む
3. 公開のページなら、外枠の足のリンク（`src/site-layout.tsx` の `footerLinks`）に足す

- ページに JavaScript とインラインの `style` を置かない。Content-Security-Policy（`src/security-headers.ts`）が自分のオリジンと Cloudflare Web Analytics のビーコンだけを許すため。見た目は `public/site.css` に書く
- Cloudflare Web Analytics のビーコンは外枠（`src/site-layout.tsx`）が全ページに置く。サイトのトークンとビーコンの送り先は `src/web-analytics.ts` の1か所にあり、CSP もそこから作る。LP に PostHog・Sentry は入れない
- セキュリティのヘッダーは `src/security-headers.ts` の1か所に置く。`vite build` がそこから `_headers` を書き出し、Worker も同じ定義を付ける（Worker の応答には `_headers` が効かない）

## 確かめる

- 変えたら `scripts/check site` を回す。整形・Lint・型検査のあと、書き出しと Worker の束ねをしてからテストを回す
- テストの継ぎ目は1つ（`src/worker.test.ts`）。書き出した `dist` と wrangler が束ねた Worker を、`wrangler.jsonc` の設定のまま別の Worker として動かし（`vitest.config.ts`）、`src/testing/fetch-site.ts` の `fetchSite` で要求を投げて、状態・ヘッダー・本文を見る。テストの実行環境の `SELF` は assets の振り分けの前段（`run_worker_first`）を通らないので使わない。ページの部品の単体テストと、Hono の経路を直に叩くテストは書かない
- 文言と見た目はテストせず、書き出したページを開いて見る
