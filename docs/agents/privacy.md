# プライバシーポリシーと公開のページ

## 公開のページ

- 公開のページは `site/` で `hono/jsx` で書き、`vite build` と `@hono/vite-ssg` で静的な HTML に書き出す。main へのマージで `.github/workflows/deploy-site.yml` が `nu-tori.app` に出す。ページの足し方と確かめ方は `site/AGENTS.md`
- ページのパス・`<title>`・説明・検索に載せるかは、ページの一覧（`site/src/site-pages.ts`）の1か所に置く
- 変えたら `scripts/check site` を回す
- 色は `DESIGN.md` のトークンを写す（`site/public/site.css`）

## ポリシーを実装に合わせて保つ

- 集めるもの、送り先、使い道、残る期間を変えるときは、同じ PR でプライバシーポリシー（`site/src/pages/privacy-page.tsx`）を直す
- App Store Connect の App Privacy の回答が変わるなら、PR の本文で開発者に知らせる。回答は App Store Connect にしか無く、エージェントは直せない
- 送り先や使い道が増えるときは、サインインの画面の同意の文も見直す（ポリシーの「改定」）
