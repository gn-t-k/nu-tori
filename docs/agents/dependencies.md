# 依存と道具の版を上げる

依存の更新は Dependabot にする。Dependabot が上げないもの（下の「ios」と「server」の手で上げるもの）は、月に一度、開発者に頼まれたときと Dependabot の PR を片付けるときに、最新を確かめて（`git ls-remote --tags`）手で上げる。

## Dependabot の PR

Dependabot の PR にコミットを足すと、Dependabot はその PR を rebase しなくなるので、手で上げるものは別の PR にし、Dependabot の PR の CI を直したら早くマージする。ロックされた Dependabot の PR でも `@dependabot recreate` は効く（足したコミットは消える）。`@dependabot rebase` が効くかは確かめていない。

## ios

- Swift: `ios/.swift-version` と、CI の `ios` のジョブの `container:` のタグと digest をそろえて上げる。swift-format が Swift に付いてくるので、整形だけの差分は別のコミットにする
- SwiftLint: `scripts/check` の版と、配布物ごとの SHA-256
- sentry-cli: `ios/ci_scripts/ci_post_xcodebuild.sh` の版と SHA-256（Sentry のリリースの登録簿 `release-registry.services.sentry.io/apps/sentry-cli/<版>` の `sentry-cli-Darwin-universal`）
- Swift Package の依存: `ios/NuToriCore/Package.swift` と `ios/OpenAPIGenerator/Package.swift` の `exact:`。上げたら `swift package update --package-path <パッケージ>` で `Package.resolved` を書き直し、`scripts/check ios --fix` で Xcode のプロジェクトの `Package.resolved` に写し、生成したクライアントを生成し直す。生成し直しただけの差分は別のコミットにする

## server

- npm の依存は Dependabot が上げる。Node（`server/.node-version`）と pnpm（`server/package.json` の `packageManager`）は手で上げる
- pnpm は、Dependabot が対応する版（2026-09-28 時点で v12 まで）にとどめる。対応が広がったら上げる
- `@cloudflare/vitest-pool-workers` が対応する Vitest の版にとどめる（2026-09-28 時点で 4.x）。Dependabot は `.github/dependabot.yml` の `ignore` で Vitest のメジャーの版上げを除いているので、対応が広がったら手で上げ、`ignore` を外す
- Better Auth の版を上げるとき（Dependabot の PR も）は、変更履歴で中核の表の変更を確かめる（1.x の中でも入ったことがある）
