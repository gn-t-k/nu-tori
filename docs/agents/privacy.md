# プライバシーポリシーと公開のページ

## 公開のページ

- 公開のページ（プライバシーポリシー）は `site/public/` に手書きの HTML で置き、main へのマージで `.github/workflows/deploy-site.yml` が `nu-tori.app` に出す
- 確かめることが無いので、`scripts/check` と CI のジョブは持たない
- 色は `DESIGN.md` のトークンを写す

## ポリシーを実装に合わせて保つ

- 集めるもの、送り先、使い道、残る期間を変えるときは、同じ PR で `site/public/privacy.html` を直す
- App Store Connect の App Privacy の回答が変わるなら、PR の本文で開発者に知らせる。回答は App Store Connect にしか無く、エージェントは直せない
- 送り先や使い道が増えるときは、サインインの画面の同意の文も見直す（ポリシーの「改定」）
