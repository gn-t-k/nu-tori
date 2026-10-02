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
