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

## Cloudflare を読む

サーバーの例外にならない振る舞い（Workers Logs、呼び出しの数・誤り・CPU 時間）は、`scripts/cloudflare` で読む。例外は Sentry で読む。環境と Worker の対応と呼ぶ先は、このスクリプトの1か所に書く。MCP の設定には Cloudflare を置かない。調べた経緯は `docs/research/cloudflare-agent-access.md`。

- 読む
  - ログ: `scripts/cloudflare logs <development|production> [何分前から] [parameters に足す JSON]`。例 `scripts/cloudflare logs production 60 '{"needle":{"value":"alarm"}}'`。JSON の `view`（既定 `events`、ほかに `calculations`・`invocations`）、`limit`、`filters`、`calculations`、`groupBys` は Workers Observability の問い合わせの形のまま渡す。保持は 7 日
  - 指標: `scripts/cloudflare metrics <development|production> [何時間前から]`。時刻と呼び出しの状態ごとの、要求・誤り・CPU 時間と壁時計の時間（単位はマイクロ秒）
- 環境は毎回引数で名指す。本番を読んだら、返事にそう書く
- 読んだ中身のうち、`accountId`、Durable Object の ID、要求 ID、要求の URL の値・ヘッダー・IP・User-Agent は、公開の Issue・PR・コメントに貼らない。貼るのは数・率・所要時間、経路の型、状態コード、例外の名前と `failedStage` まで
- トークンは読むだけにする。アカウントのトークンで、Workers の役割 `Metadata Read-Only` を `nu-tori-development` と `nu-tori-production` に絞ったものと、`Account Analytics Read` だけを付ける（このトークンでログの問い合わせが通ることを 2026-10-09 に確かめた）。デプロイ用の `CLOUDFLARE_API_TOKEN` は使わない
  - Mac: シェルの設定に `NU_TORI_CLOUDFLARE_ACCOUNT_ID` と `NU_TORI_CLOUDFLARE_READ_TOKEN` を書く
  - Claude Code on the web と Cursor の Cloud Agents: 同じ2つを、Sentry のトークンと同じ置き場に置く。Cursor の `NU_TORI_CLOUDFLARE_READ_TOKEN` は Runtime Secret にする
- AI Gateway のログは、まだ読まない（ゲートウェイが無い）。ゲートウェイを作るときに、トークンに `AI Gateway Read` を足し、スクリプトにゲートウェイの ID とログを読む口を足す。そのときも、要求と応答の本文（`request_head`・`response_head`、`.../logs/<id>/request`・`/response`）は読まない
- アカウント ID かトークンの無い場所で呼ぶと `Not authenticated` で止まる。そのときは開発者に、上のどちらかの置き場に2つとも置くよう頼む

## PostHog を読む

利用の数（出来事の件数、続き具合、ファネル、変えた前後の差）は、`scripts/posthog-query` で読む。PostHog の Query API を直接呼び、置き場（EU）と鍵の受け取り方は、このスクリプトの1か所に書く。MCP の設定には PostHog を置かない。調べた経緯は `docs/research/posthog-agent-access.md`。

- 読む: 標準入力に Query API の query を JSON で渡す。例 `echo '{"kind":"HogQLQuery","query":"SELECT count() FROM events WHERE timestamp >= now() - INTERVAL 7 DAY"}' | scripts/posthog-query`。続き具合は `RetentionQuery`、ファネルは `FunnelsQuery`、ほかは `HogQLQuery`（SQL）。率は応答に無いので、件数から自分で割る
- PostHog に送るのは本番だけ（サーバーも、iOS のリリースビルドだけ）なので、環境は名指さない。読んだのは本番の数になる
- 期間は8週ほどに絞り、人の一覧と出来事の行（`EventsQuery`、`SELECT *`）は取らない
- 読んだ中身のうち、`distinct_id`（アカウント ID）、`person_id`、`$session_id`・`$device_id`・`$anon_distinct_id` などの ID、人の属性、1人ごとの行は、公開の Issue・PR・コメントに貼らない。貼るのは集計（件数・率・差・中央値の秒、版・週ごとの内訳）までで、1〜2人の内訳は「数人」とまとめる
- 鍵は読むだけにする。個人の API キーで、スコープは `query:read` だけ（preset「Performing analytics queries」）、届く範囲は nu-tori のプロジェクトだけにする（この鍵で `HogQLQuery` と `RetentionQuery` が通ることを 2026-10-09 に確かめた）。`query:read` でも `persons` の表は読めるので、ID を外に出さないことは上の決まりで守る。Worker が人を消す `POSTHOG_PERSONAL_API_KEY` は使わない
  - Mac: シェルの設定に `NU_TORI_POSTHOG_PROJECT_ID`（プロジェクトの URL の数字）と `NU_TORI_POSTHOG_READ_KEY` を書く
  - Claude Code on the web と Cursor の Cloud Agents: 同じ2つを、Sentry のトークンと同じ置き場に置く。Cursor の `NU_TORI_POSTHOG_READ_KEY` は Runtime Secret にする。Claude Code on the web のネットを Custom にしているなら、`eu.posthog.com` を足す
- Query API はいまは無料だが、PostHog はいずれ課金すると書いている。上限はプロジェクトごとに 1 時間 2,400 回・1 分 240 回・同時 3 本・実行 10 秒で、ほかに個人の API キーで読む分には、プロジェクトごとに 1 時間に読む量の予算がある（量は公開されていない）。どれかを超えると `429` が返り、読む量の予算なら `api_queries_budget_exceeded` が付く
- プロジェクトの ID か鍵の無い場所で呼ぶと `Not authenticated` で止まる。そのときは開発者に、上のどちらかの置き場に2つとも置くよう頼む

## 本番の知らせを Issue にする

`.github/workflows/production-alerts.yml` が毎時 17 分に `scripts/production-alerts sentry` を回し、本番（`environment:production`）の Sentry の、新しい・急に増えた・再発した課題を、`needs-triage` の Issue にしてロックする。エージェントは `/triage` で拾い、中身は `scripts/sentry` で読む。調べた経緯は `docs/research/alerts-to-issues.md`。

- Issue の題は `Sentry <短い ID>: <例外の型> in <関数>`。本文に載せるのは、短い ID・状態・型・関数・版・OS・件数と利用者の数・最初と最後の発生・Sentry の URL だけで、スクリプトはこれらの欄だけを Sentry から取る。例外のメッセージ（Sentry の課題の題）は取らない
- 本文の印 `<!-- sentry-issue: <短い ID> -->` で同じ課題の Issue を探し、`<!-- sentry-state: <状態> -->` で最後に知らせた状態を覚える。状態が変わったら、開いた Issue にはコメントを足し、閉じた Issue しか無ければ前の Issue を指して新しく作る。状態が同じなら何もしないので、Sentry で解決せずに Issue だけを閉じても立て直さない。ただし、Issue を completed で閉じたあとにまた起きたら、同じ状態でも新しく作る（wontfix で閉じたものは立て直さない）。ロックが抜けた Issue は、次の回でロックする。印は、ワークフローと、リポジトリの持ち主・メンバー・コラボレーターが書いたものだけを信じる
- 1回に書くのは5件まで（作る・コメントする）。残りは次の回で拾う
- 秘密の値は Sentry の読むだけのトークン `NU_TORI_SENTRY_READ_TOKEN` だけで、main からだけ使える Environment `production-alerts` に置く。Issue は `GITHUB_TOKEN` で書く
- Mac で確かめるときは `scripts/production-alerts sentry --dry-run`。GitHub に書かず、作る Issue の題とコメントする先だけを出す
- 公開のリポジトリでは、60 日動きが無いと定期実行が止まる。止まったら Actions の画面で入れ直す

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
