# Xcode Cloud から Sentry へ dSYM を上げる

調査日: 2026-09-26
対象: Issue #54「Xcode Cloud と main のルールセットを設定する」に足した問い「dSYM を Xcode Cloud のビルドのあとに Sentry へ上げる」。前に調べた Sentry の事実は `docs/research/observability.md` の「Sentry」の節

> **確認の方法と限界**
> - Apple の文書は JSON（`https://developer.apple.com/tutorials/data/documentation/xcode/<ページ>.json`）で本文を読んだ。Sentry の文書は docs.sentry.io のページと原稿（getsentry/sentry-docs、コミット db71474）を読んだ。sentry-cli は getsentry/sentry-cli の main（c880db5、3.8.0 の直後）のソースと CHANGELOG、3.8.0 のタグの `src/commands/debug_files/upload.rs` を読んだ。
> - Sentry と Xcode Cloud の実アカウントでは動かしていない。二次情報は使っていない（利用者の報告の Issue を1つだけ参考に挙げた）。

## 結論の要約

- **Sentry の文書に、Xcode Cloud から dSYM を上げる手順は無い**。挙がっている方法は sentry-cli、Fastlane のプラグイン、Xcode のビルドの Run Script の3つ（本文を探したが記述なし、S1）
- **Developer（無料）のプランで sentry-cli の dSYM のアップロードが使えるかは、文書では分からない**。料金のページの比較表で「API」の行は Developer にだけ印が無く、sentry-cli は API を通して上げるが、この「API」がアップロードを含むかはどこにも書かれていない。debug files のプランごとの制限も書かれていない（本文を探したが記述なし、S2・S3）。**最初のアーカイブで実際に上がるかを確かめる**
- Xcode Cloud の `ci_scripts/ci_post_xcodebuild.sh` から、版と SHA-256 を固定した sentry-cli を落として `debug-files upload` を呼べば、Apple と Sentry の文書の範囲で組める（本文からの読み取り、A1・A2・S1・S4）

## Xcode Cloud のカスタムビルドスクリプト

- 置き場所は、プロジェクトと同じディレクトリの `ci_scripts`。リポジトリに1つだけ（本文で確認、A1）。このリポジトリでは `ios/ci_scripts/`
- `ci_post_xcodebuild.sh` は、xcodebuild が失敗しても、どのアクションでも動く。アクションは `CI_XCODEBUILD_ACTION`（`archive` など）、結果は `CI_XCODEBUILD_EXIT_CODE`（0 で成功）で見分ける（本文で確認、A1・A2）
- `CI_ARCHIVE_PATH` は archive のアクションのときだけ使える（本文で確認、A2）。実際の値は文書に無い（利用者の報告では `/Volumes/workspace/build.xcarchive`、R1）
- アーカイブには dSYM が入る。Debug Information Format を「DWARF with dSYM File」にする（本文で確認、A3）。アーカイブの中のどのディレクトリに入るかは Apple の文書に無い
- 実行できるファイルにする（`chmod +x`）。shebang が無いか実行権限が無いと `zsh` で動き、失敗することがある。0 以外で終わるとビルドが失敗する（本文で確認、A1）
- 秘密の値は、ワークフローの Environment に置き、「Secret」にする。ログでは伏せられる（本文で確認、A1・A4）
- 外への通信は HTTP のプロキシを通り、`HTTP_PROXY`・`HTTPS_PROXY` が渡る（本文で確認、A2）。sentry-cli の文書は小文字の `http_proxy` を読むと書く（本文で確認、S5）。sentry-cli は libcurl で通信し、`http_proxy` も設定も無ければ proxy を指定しない（ソースで確認、3.8.0 の `Cargo.toml`・`src/api/mod.rs`・`src/config.rs`）。libcurl は、proxy を指定されないと、URL の scheme ごとの環境変数（`http_proxy` など）を読む（本文で確認、S10）。大文字の `HTTPS_PROXY` を読むかは、このページに書かれていない。**大文字だけで sentry-cli が通るかは、動かしては確かめていない**
- `sudo` は使えない。スクリプトが作ったファイルは、ほかのスクリプトからは見えないことがある（本文で確認、A1・A5）

## sentry-cli

- 形: `sentry-cli debug-files upload --auth-token <token> --org <org> --project <project> <パス>`。渡したパスを再帰的に探し、上げ済みのものは飛ばす（本文で確認、S1・S4）。`--type dsym` で Mach-O だけにする（ソースで確認、`upload.rs`）
- 認証は組織のトークン（接頭辞 `sntrys_`）（本文で確認、S4・S6）。組織のトークンは組織と URL を中に持ち、`--org` が無ければトークンの組織を使い、URL もトークンのものを優先する（ソースで確認、`src/config.rs`、CHANGELOG 2.34.0）。EU（`de.sentry.io`）の組織でも `SENTRY_URL` は要らない作りと読めるが、明言した文書は無い（本文からの読み取り）
- 環境変数は `SENTRY_AUTH_TOKEN`・`SENTRY_ORG`・`SENTRY_PROJECT`・`SENTRY_URL`（本文で確認、S5）
- 最新は 3.8.0（2026-09-16）。macOS の universal の配布物は `sentry-cli-Darwin-universal`。チェックサムのファイルは無いが、Sentry のリリースの登録簿がファイルごとの SHA-256 を出す。3.8.0 の universal は `2c26914636c47ab9bf9e710484ad7b44d371cbec8bd29cafb36b3cf877bf4285` で、GitHub の表示とも、落としたファイルとも一致した（本文で確認、S7・S8）
- `https://sentry.io/get-cli/` の入れ方は、既定で `/usr/local/bin` に `sudo` で入れ、チェックサムは応答のヘッダと比べるだけなので、Xcode Cloud には合わない（本文で確認、S9）

## 出典

- A1: Writing custom build scripts — https://developer.apple.com/documentation/xcode/writing-custom-build-scripts
- A2: Environment variable reference — https://developer.apple.com/documentation/xcode/environment-variable-reference
- A3: Building your app to include debugging information — https://developer.apple.com/documentation/xcode/building-your-app-to-include-debugging-information
- A4: Xcode Cloud workflow reference（Custom environment variables）— https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference
- A5: Making dependencies available to Xcode Cloud — https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud
- S1: Uploading Debug Symbols（iOS）— https://docs.sentry.io/platforms/apple/guides/ios/dsym/
- S2: Pricing — https://sentry.io/pricing/
- S3: Debug Files（保存は 90 日、使われないと消える）— https://docs.sentry.io/platforms/apple/guides/ios/data-management/debug-files/
- S4: Debug Information Files（CLI）— https://docs.sentry.io/cli/dif/
- S5: Configuration and Authentication（CLI）— https://docs.sentry.io/cli/configuration/
- S6: Auth Tokens — https://docs.sentry.io/account/auth-tokens/
- S7: sentry-cli 3.8.0 — https://github.com/getsentry/sentry-cli/releases/tag/3.8.0
- S8: Release registry — https://release-registry.services.sentry.io/apps/sentry-cli/3.8.0
- S9: Installation（CLI）— https://docs.sentry.io/cli/installation/
- S10: libcurl CURLOPT_PROXY（Environment variables）— https://curl.se/libcurl/c/CURLOPT_PROXY.html
- R1: getsentry/sentry-cli#2919（利用者の報告）— https://github.com/getsentry/sentry-cli/issues/2919
