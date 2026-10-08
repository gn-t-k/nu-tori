# エージェントの道具と CI

## スキル

mattpocock/skills は `skills-lock.json` で管理し、`.claude/hooks/session-start.sh` がクラウドのセッションの開始時に更新を確かめる。更新は、作業ツリーに触れずに別の worktree に当て、作業の PR とは別の PR（ブランチ `claude/update-mattpocock-skills-<日付>`）で取り込む。更新で上書きされるため、lock にある skill は直接編集しない。Claude Code は `.claude/skills/`（`.agents/skills/` へのリンク）を、Codex は `.agents/skills/` を読む。`.claude/skills/` にだけある `model-based-ui-design` は、Codex からは見えない。

- lock の外の skill は、`.agents/skills/<名前>/` に置いて `.claude/skills/` からリンクする。自動更新は lock にある名前だけを入れ直し、ほかは触らない。この決まりより前に置いた `model-based-ui-design` は `.claude/skills/` にだけあり、移すかは決めていない
- `byethrow` は、`@praha/byethrow-docs` の `init claude` が書き出す skill を、`server/` の依存から docs を引く形に直したもの
- `erd-design` は、開発者がほかのリポジトリでも使う自作の skill。どのリポジトリでも使える形に保ち、このリポジトリに固有の前提は `docs/agents/table-design.md` に書く

## hook

確かめることは `scripts/check` と CI に置き、Claude Code の hook は便利のためだけに使う（Codex と Cursor では hook が動かない）。

- `session-start.sh`（クラウドで始めたとき）: Swift を入れ、mattpocock/skills の更新を確かめる
- `warn-behind-main.sh`（クラウドで続けたとき。resume・compact・clear）: 作業ツリーが origin/main より遅れていたら知らせる。長いセッションのあいだに main が進み、古い版の働き方の文書を読んでチケットを切り違えたため

## MCP

- MCP のサーバーは、Claude Code（`.mcp.json`）・Codex（`.codex/config.toml`）・Cursor（`.cursor/mcp.json`）の3つの設定に同じものを置き、版や環境変数は起動スクリプト（`scripts/mobilebuildmcp`）の1か所に書く。Codex はプロジェクトを信頼したとき、Cursor は Customize でサーバーを一度オンにしたときに読む
- Xcode の MCP（`xcrun mcpbridge`）は、各ツールの MCP の設定に直接置かず、MobileBuildMCP の中継で呼ぶ

## Sentry を読む

Sentry の課題・イベント・スタック・端末・版・件数は、`scripts/sentry`（Sentry の公式の CLI、npm の `sentry`）で読む。版・テレメトリの停止・組織は、このスクリプトの1か所に書く。MCP の設定には Sentry を置かない。調べた経緯は `docs/research/sentry-agent-access.md`。

- 読む: `scripts/sentry issue list <project> --json`、`scripts/sentry issue view <短い ID> --json`（課題と最新のイベント）、`scripts/sentry issue events <短い ID> --full`（イベントごとのスタック）
- 書き込みのコマンド（`resolve`、`archive`、`merge` など）と、Seer を使うコマンド（`explain`、`plan`）は使わない
- 読んだイベントの中身（端末の ID、利用者、要求のヘッダー）は、公開の Issue・PR・コメントに貼らない。貼るのはスタックの関数名と、版・OS・件数まで
- 認証は読むだけにする
  - Mac: 開発者が `scripts/sentry auth login --read-only` を一度走らせる
  - Claude Code on the web と Cursor の Cloud Agents: 読むだけの個人のトークン（スコープ `org:read`・`project:read`・`team:read`・`event:read`・`member:read`）を、環境変数 `NU_TORI_SENTRY_READ_TOKEN` に置く。Claude Code on the web は個人の環境に置き、ネットを Custom にして `sentry.io` と `*.sentry.io` を足す（既定の一覧も残す）。Cursor は Cloud Agents の Secrets に置く
  - dSYM を上げる組織のトークン（Xcode Cloud の `SENTRY_AUTH_TOKEN`）は課題を読めないので、使い回さない
- 認証の無い場所で呼ぶと `Not authenticated` で止まる。そのときは開発者に、上のどれかを頼む

## App Store Connect を読む

Xcode Cloud のビルドの成否は、GitHub の check run（app は `xcode-cloud`）で見る: `gh api repos/gn-t-k/nu-tori/commits/<sha>/check-runs`。失敗の中身、TestFlight のビルドの状態、TestFlight のフィードバックとクラッシュのログは、`scripts/app-store-connect get '<パス>'` で読む。GET だけを送り、鍵の読み方と JWT の作り方は、このスクリプトの1か所に書く。MCP の設定には置かない。調べた経緯は `docs/research/app-store-connect-agent-access.md`。

- 読む（`<app>` はアプリの ID `6816842705`。`--all` で次のページをたどる。出力はファイルかパイプで渡し、`echo "$変数"` で受け渡さない。zsh の `echo` は `\n` を改行に変えて JSON を壊す）
  - Xcode Cloud: `/v1/ciProducts?filter[app]=<app>`、`/v1/ciProducts/<id>/buildRuns?sort=-number&limit=5`、`/v1/ciBuildRuns/<id>/actions`、`/v1/ciBuildActions/<id>/issues`
  - TestFlight に配られたか: `/v1/builds?filter[app]=<app>&sort=-uploadedDate&limit=5&include=buildBetaDetail,betaGroups`（`processingState` が `VALID`、`buildBetaDetail` の `internalBuildState` が `IN_BETA_TESTING`）
  - フィードバック: `/v1/apps/<app>/betaFeedbackCrashSubmissions`、`/v1/betaFeedbackCrashSubmissions/<id>/crashLog`、`/v1/apps/<app>/betaFeedbackScreenshotSubmissions`
- 読んだフィードバックのメール・名前・コメント・スクリーンショット・クラッシュのログの全文・期限つきの URL は、公開の Issue・PR・コメントに貼らない。貼るのは、ビルド番号、状態、関数名、版・OS・機種、件数まで
- キーは、チームのキーで役割 Developer。読むだけの役割は無く、Developer でもフィードバックを消せるので、スクリプトを通さずに API を呼ばない
  - Mac: `.p8` を `~/.appstoreconnect/private_keys/AuthKey_<Key ID>.p8` に置き、シェルの設定に `NU_TORI_ASC_KEY_ID` と `NU_TORI_ASC_ISSUER_ID` を書く
  - Claude Code on the web と Cursor の Cloud Agents: `NU_TORI_ASC_KEY_ID`、`NU_TORI_ASC_ISSUER_ID`、`NU_TORI_ASC_PRIVATE_KEY`（`.p8` を base64 の1行にしたもの）を、Sentry のトークンと同じ置き場に置く。Cursor の `NU_TORI_ASC_PRIVATE_KEY` は Runtime Secret にする
- 鍵の無い場所で呼ぶと `Not authenticated` で止まる。そのときは開発者に、上のどれかを頼む

## CI

- CI は変わったパスでジョブを分け、main のルールセットでは `check.yml` の `ios-app` 以外のジョブをすべて必須にする。飛ばすのはジョブの条件（変わったファイルを判定するステップ）で行い、文書（`*.md`）だけの変更ではジョブを飛ばす。ワークフローの `paths` で飛ばすと、必須のチェックが保留のまま残る。必須にしないワークフロー（デプロイ、`ios-ui-test.yml`）は `paths` で飛ばしてよい
- GitHub Actions の秘密の値は、main からだけ使える Environment に置く（ADR-0010）
- 依存の PR をマージし、落ちた PR の Issue を扱う `dependency-pr.yml` と、Swift Package を上げる `update-swift-packages.yml` は、`GITHUB_TOKEN` でなく、このリポジトリ用の GitHub App のトークン（`actions/create-github-app-token`）で GitHub を操作する。`GITHUB_TOKEN` で出した PR やマージは、ほかのワークフロー（check、deploy、`ios-ui-test.yml`）を起動しないため。App の Client ID は変数 `DEPENDENCY_APP_CLIENT_ID`、秘密鍵は秘密の値 `DEPENDENCY_APP_PRIVATE_KEY` として、main からだけ使える Environment `dependency-updates` に置く。依存の PR の扱い方は `docs/agents/dependencies.md`
- 開発用の環境で主な流れを確かめるジョブ（`deploy.yml` の `verify-development`）は、開発用の Worker のデプロイのあとに、`server/e2e/verify-development.ts` が本物の API を通す。必須のチェックにせず、落ちたらこのジョブが赤くなるだけで、本番のデプロイは待たない。使う秘密の値 `E2E_SIGN_IN_SECRET` は、開発用の Environment の GitHub Actions の秘密の値と、開発用の Worker の秘密の値（`wrangler secret put E2E_SIGN_IN_SECRET`）に、同じ値を置く。本番の Environment にも本番の Worker にも置かない（守り方は `server/AGENTS.md` の「確かめのジョブのためのサインインの口」）
- iOS のアプリは、PR ではビルド（UI テストのビルドを含む）までを確かめ、UI テストは main への push と、`ui-test` のラベルを付けた PR と、手で始めたときだけ回す。main で落ちたら、ワークフローが Issue を1つ立て、緑に戻ったら閉じる。その Issue は次の PR より先に直す

  **Why:** UI テストは画面が増えるほど延び、シミュレータの起動に数分かかる。PR のたびに回すと、画面がまだ揃わないうちから開発者もエージェントも十数分待っていた

## ウィザード

- `/wizard` で作るウィザードは macOS の bash 3.2 で動く。日本語の文字のすぐ前の変数は `${name}` で囲む（bash 3.2 は、続く多バイト文字を変数の名前に含めて unbound variable で止まる）。書いたら `grep -nP '\$[A-Za-z_]\w*[^\x00-\x7F]' <ウィザード>` が0件になることを確かめる
- ひな形の `set_secret` はリポジトリの秘密の値だけを置く。GitHub Actions の Environment の秘密の値（ADR-0010）は、段の中で `gh secret set <名前> --env <Environment> --repo gn-t-k/nu-tori` で置く
