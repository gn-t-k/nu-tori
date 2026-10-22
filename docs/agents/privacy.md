# プライバシーポリシーと公開のページ

## 公開のページ

- 公開のページは `site/` に置き、main へのマージで `.github/workflows/deploy-site.yml` が `nu-tori.app` に出す。足し方と確かめ方は `site/AGENTS.md`
- 色は `DESIGN.md` のトークンを写す（`site/public/site.css`）

## 利用規約と特定商取引法に基づく表記

条と事項の中身の正本は #593 の解決コメント。ページは `site/src/pages/terms-page.tsx`（`/terms`）と `site/src/pages/legal-page.tsx`（`/legal`）。

- 特商法の表記の住所・電話番号は、`support@nu-tori.app` に請求が来たら、請求から3日以内にメールで返す。値そのものは、リポジトリ・Issue・PR・コメントに書かない
- 利用規約を改定するときは、ページの改定日と、課金のサーバーが持つ規約の版（同意を残す `terms_agreements` の版）をそろえる。利用者に不利な変更（価格の条件、使える機能を減らす、1日の回数の上限を下げる、など）は、仕様「告知と利用の停止」の同意の取り直しに回す
- 価格を変えるときは、App Store Connect の価格を変えるのと同じ日に、`site/src/subscription-prices.ts`（特商法の表記と LP の料金の節が読む）を直した PR を main に入れる。利用規約は価格を数字で書かないので改定しない

**Why:** 規約の版とページの改定日がずれると、どの版に同意したかを示せない。表記の価格と App Store の請求がずれると、特商法の表示の誤りになる。

## ポリシーを実装に合わせて保つ

- 集めるもの、送り先、使い道、残る期間を変えるときは、同じ PR でプライバシーポリシー（`site/src/pages/privacy-page.tsx`）を直す
- App Store Connect の App Privacy の回答が変わるなら、PR の本文で開発者に知らせる。回答は App Store Connect にしか無く、エージェントは直せない
- 送り先や使い道が増えるときは、サインインの画面の同意の文も見直す（ポリシーの「改定」）
- `nu-tori.app` だけで集めるもの（Cloudflare Web Analytics の訪問、LP の版の Cookie）を変えるときは、ポリシーの「1. 集める情報と集め方」の項と、「2. 使い道」「5. 保存する期間と削除」の行を一緒に直す。アプリの外のウェブなので、App Privacy の回答とサインインの同意の文は変えない
