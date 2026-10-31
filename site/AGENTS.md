# site

`nu-tori.app` のページ。`hono/jsx` で書いたページを `vite build` と `@hono/vite-ssg` で静的な HTML に書き出し（`src/site-app.tsx`）、`/` と `/_lp/*` だけを振り分けの Worker（`src/worker.ts`）に通す。ほかのパスは Worker を通らず、静的な asset のまま返る。書く・直すときは `docs/agents/privacy.md` も読む。

## ページを足す

1. `src/pages/<名前>-page.tsx` に `SitePage`（`src/site-page.ts`）を1つ書く。ページのパス（`outputPath`）・`<title>`・説明・検索に載せるか（`kind`）は、このページの `SitePage` に置く。`outputPath` は末尾のスラッシュ無し（`/terms` → `terms.html`）にする。公開のページは、`kind` を `public` にして足のリンクの文を `footerLabel` に書き、`outputPath` がそのまま正規の URL のパスになる（ほかの `kind` の正規の URL は `src/site-page.ts` の型のコメント）
2. ページの一覧（`src/site-pages.ts`）に並べる。一覧はページを並べるだけで、書き出し・`sitemap.xml`・`<head>`・外枠の足のリンク・テストがここからページを読み、公開のページの並びが足のリンクの並びになる

- ページに JavaScript とインラインの `style` を置かない。Content-Security-Policy（`src/security-headers.ts`）が自分のオリジンと Cloudflare Web Analytics のビーコンだけを許すため。見た目は `public/site.css` に書く
  - 例外は、LP の版 a の工夫の節の見本を動かす `public/landing-a.js` だけ（#660）。中身と文は書き出しで全部作り、スクリプトは選んだものを見せて文を入れ替えるだけにする。スクリプトが読む値は、実行されない `<script type="application/json">` に置く
- `public/site.css` の `font-size` は px で書き、`DESIGN.md` の typography の最小より小さくしない（`scripts/check site` が確かめる）
- Cloudflare Web Analytics のビーコンは外枠（`src/site-layout.tsx`）が全ページに置く。サイトのトークンとビーコンの送り先は `src/web-analytics.ts` の1か所にあり、CSP もそこから作る。LP に PostHog・Sentry は入れない
- セキュリティのヘッダーは `src/security-headers.ts` の1か所に置く。`vite build` がそこから `_headers` を書き出し、Worker も同じ定義を付ける（Worker の応答には `_headers` が効かない）

## LP の版を足す・外す

振り分けの Worker が、`wrangler.jsonc` の `LP_VARIANTS` から訪問者ごとに版を等しい確率で選び、Cookie `nu_tori_lp`（版の名前だけ、30日）で覚えて、`/_lp/<版>/` を `/` で返す。`LP_VARIANTS` が空のあいだは仮のページを返す。

- 足す: `src/pages/landing-<版>-page.tsx` に `createLandingVariantPage`（`src/create-landing-variant-page.tsx`）で版のページを1つ書いてページの一覧に足し、`LP_VARIANTS` に版の名前を1つ足す。版の名前は英小文字と数字だけ。バッジのリンクは版の名前から `ct=lp-<版>` を作るので、App Store Connect のキャンペーンでその版のダウンロード数を見る
- 外す: `LP_VARIANTS` から名前を消す。その版の Cookie を持つ人は、次に開いたときに残った版に振り直される。版のページは、一覧から消すまで書き出されるが、`/_lp/*` を直に開くと `/` へ転送するので外からは見えない
- バッジは `AppStoreBadge`（`src/app-store-badge.tsx`）を1ページに1つ置く。置いたページの足にだけ Apple の商標の行が出る。アプリの ID と提供者のトークンは `src/app-store-listing.ts` の1か所に置く

## 告知を足す

告知のページ（`/announcements`）は、`src/announcements/` の告知のファイルを集め、出した日の新しい順に並べる。ファイルが無いときは「今お知らせしていることはありません。」を出す。

1. `src/announcements/<出した日>-<英小文字の名前>.tsx`（例: `2026-11-03-sync-outage.tsx`）に、`announcement` の名前で `Announcement`（`src/announcement.ts`）を1つ出す。出した日・題・何が起きたか・影響・ユーザーができることを書く。問い合わせ先は告知のページが足すので書かない
2. 書いたら `scripts/check site` を回し、`pnpm exec vite build` で書き出した `dist/announcements.html` を開いて文を読む。main に入れれば `deploy-site.yml` が出す

- 公表には特定の個人が分かること（アカウント ID、漏れた中身、ユーザーの記録）を書かない（`docs/agents/production-incidents.md`）
- 告知のページは、ページの一覧には1つだけ載る。告知ごとのページは作らない

## 掲載情報を直す

App Store Connect に入れる掲載情報（名前、サブタイトル、プロモーション用テキスト、説明文、キーワード欄、審査へのメモ、URL、著作権の欄の形、カテゴリ）は `src/app-store-connect-listing.ts` の1か所に、スクリーンショット5枚の見出しと載せる生の画面は `src/app-store-screenshots.ts` に置く。どちらもページには出さず、テストと合成のコマンドと wizard が読む。アプリの ID と提供者のトークン（`src/app-store-listing.ts`）はバッジが使う別のもの。変える順は `docs/agents/marketing.md` の「掲載情報の置き場と変える手順」。

- 文言の欄（サブタイトル、プロモーション用テキスト、説明文、見出し）は `ListingCopy`（`src/listing-copy.ts`）で書き、仮の文は `status: "draft"`、決めた文は `"final"` にする。仮の文が残るあいだ、wizard は App Store Connect に入れる段を始めない
- 説明文の URL は、ページの一覧から作る（`publicPageUrl`）。URL を手で書かない
- 欄を足したら、`AppStoreConnectListing` の型に足し、上限や決まりがあれば `src/listing-rule-violations.ts` に1つ足して、外れたときに挙がるテストを `src/listing-rule-violations.test.ts` に足す。文言の欄なら `draftListingFields` にも足す
- スクリーンショットの見出しは `src/app-store-screenshots.ts` に書く。合成のコマンドが Node のまま読むので、このファイルはほかのモジュールを import しない（`import type` はよい）。生の画面を足したら、`RawScreenName` にも足す
- wizard は `node src/app-store-connect-listing-command.ts drafts`（仮の文の欄を挙げ、残っていれば 1 で終わる）と `json`（掲載情報の JSON）で読む。ページの `.tsx` を読むので、Vite の `runnerImport` で読み込む

## 合成する

合成のコマンド（`screenshots/compose-screenshots-command.ts`）は、生の画面のフォルダ（`<名前>.png`）を受け、Apple の端末の枠に入れた画像を書き出す。枠と画面を HTML で組み、`public/site.css` を読んだ Playwright の Chromium で画像にする。外のものは読み込まないので、同じ入力からは同じ画像になる。

- 書き出すもの:
  - LP の手順の絵3枚（生の画面の `step-weigh`・`step-photo`・`step-guide`）を `public/landing-a/steps/<名前>.webp` に、地を透過で、LP の場所取り（`.lp-shot`）の幅 200 の2倍の密度で。LP が `<img>` に書く置き場と幅・高さは `src/pages/landing-a/step-shots.json` に書く
  - 掲載用のスクリーンショット5枚を `src/app-store-screenshot-images/<01〜05>.png` に、1320×2868 の透過なし（アルファのチャンネルなし）で。地の色と見出しと、枠に入れた生の画面を並べる。見出しと載せる生の画面は `src/app-store-screenshots.ts` から読む
- 回し方: `site/` で `node screenshots/compose-screenshots-command.ts <生の画面のフォルダ>`。生の画面が足りなければ、足りない名前を挙げて止まる。掲載用の生の画面がまだ無いうちは `--landing-only` で LP の絵だけを書き出す。書き出した画像と JSON をコミットし、生の画面はコミットしない
- 端末の枠: Apple Design Resources（https://developer.apple.com/design/resources/）の iPhone の枠の PNG を、開発者が自分で使用許諾に同意して落とし、`screenshots/bezel/iphone.png` に置く（`.gitignore` している）。別の置き場の枠は `--bezel <PNG>` で渡す。使用許諾が配り直しを禁じるので、枠の画像はリポジトリにも Issue・PR にも置かない。枠は手を加えずに使い、画面の所が透けた穴の位置と角の丸みは、コマンドが画像から読む。生の画面と同じ機種（6.9 インチ）の枠を選ぶ
- 枠の無いクラウドのセッションでは、合成の結果を作らない（iPhone の絵を自分で描かない。#649）。枠のある Mac で回すよう開発者に頼む
- 書き出したら、絵を Artifact に載せて開発者が見る（見た目はテストしない）

## 確かめる

- 変えたら `scripts/check site` を回す。整形・Lint・型検査のあと、書き出しと Worker の束ねをしてからテストを回す
- ページのテストの継ぎ目は1つ（`src/worker.test.ts`）。書き出した `dist` と wrangler が束ねた Worker を、`wrangler.jsonc` の設定のまま別の Worker として動かし（`vitest.config.ts`）、`src/testing/fetch-site.ts` の `fetchSite` で要求を投げて、状態・ヘッダー・Cookie・本文に含まれるリンク（ページの中の目印の id を含む）を見る。テストの実行環境の `SELF` は assets の振り分けの前段（`run_worker_first`）を通らないので使わない。ページの部品の単体テストと、Hono の経路を直に叩くテストは書かない
- LP の版の振り分けは、本番の `LP_VARIANTS` に頼らず、版を a と b にした2つめの Worker（`src/testing/fetch-site-with-landing-variants.ts`）で確かめる。b はテストだけの版で、`vite build --mode test` が本番のページに足して `.wrangler/test-dist` に書き出す（`src/testing/test-site-app.tsx`）。版を選ぶ乱数は、その Worker のテストだけの入口（`src/testing/landing-variants-test-worker.ts`）で決める
- 合成のコマンドは、Worker の継ぎ目と別に、`screenshots/compose-screenshots.test.ts` を Node の vitest（`vitest.screenshots.config.ts`）で回す。決まった大きさの単色の PNG を置いた作り物の生の画面のフォルダと、穴の空いた単色の代わりの枠を渡し、書き出したファイルの名前と枚数、画像の幅・高さと透過の有無（WebP は `testing/read-image-size.ts`、掲載用の PNG は `testing/read-png-size.ts`）、JSON の幅・高さだけを見る。合成の HTML と CSS の中身は見ない。Chromium は `scripts/check site` が入れる（Linux では、入れる権限があればそのライブラリも）。合成のコマンドの型は、DOM の型を読む `screenshots/tsconfig.json` で見る
- 掲載情報は、ページの継ぎ目と別に、`src/listing-rule-violations.test.ts` で今の値が決まりに外れないことと、外れたときに決まりの名前が挙がることを見る。文言の正しさは見ない
- 文言と見た目はテストせず、書き出したページを開いて見る。テストで日本語の文字列を照らすと、`.oxlintrc.json` の `nu-tori/no-wording-in-test` が落とす（`describe`・`test` の名前は除く）
