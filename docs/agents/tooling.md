# エージェントの道具と CI

## スキル

mattpocock/skills は `skills-lock.json` で管理し、`.claude/hooks/session-start.sh` で自動更新している。更新で上書きされるため、lock にある skill は直接編集しない。Claude Code は `.claude/skills/`（`.agents/skills/` へのリンク）を、Codex は `.agents/skills/` を読む。`.claude/skills/` にだけある `model-based-ui-design` は、Codex からは見えない。

- lock の外の skill は、`.agents/skills/<名前>/` に置いて `.claude/skills/` からリンクする。自動更新は lock にある名前だけを入れ直し、ほかは触らない。この決まりより前に置いた `model-based-ui-design` は `.claude/skills/` にだけあり、移すかは決めていない
- `byethrow` は、`@praha/byethrow-docs` の `init claude` が書き出す skill を、`server/` の依存から docs を引く形に直したもの
- `erd-design` は、開発者がほかのリポジトリでも使う自作の skill。どのリポジトリでも使える形に保ち、このリポジトリに固有の前提は `docs/agents/table-design.md` に書く

## hook

確かめることは `scripts/check` と CI に置き、Claude Code の hook は便利のためだけに使う（Codex と Cursor では hook が動かない）。

## MCP

- MCP のサーバーは、Claude Code（`.mcp.json`）・Codex（`.codex/config.toml`）・Cursor（`.cursor/mcp.json`）の3つの設定に同じものを置き、版や環境変数は起動スクリプト（`scripts/mobilebuildmcp`）の1か所に書く。Codex はプロジェクトを信頼したとき、Cursor は Customize でサーバーを一度オンにしたときに読む
- Xcode の MCP（`xcrun mcpbridge`）は、各ツールの MCP の設定に直接置かず、MobileBuildMCP の中継で呼ぶ

## CI

- CI は変わったパスでジョブを分け、main のルールセットでは `check.yml` の `ios-app` 以外のジョブをすべて必須にする。飛ばすのはジョブの条件（変わったファイルを判定するステップ）で行い、文書（`*.md`）だけの変更ではジョブを飛ばす。ワークフローの `paths` で飛ばすと、必須のチェックが保留のまま残る。必須にしないワークフロー（デプロイ、`ios-ui-test.yml`）は `paths` で飛ばしてよい
- GitHub Actions の秘密の値は、main からだけ使える Environment に置く（ADR-0010）
- iOS のアプリは、PR ではビルド（UI テストのビルドを含む）までを確かめ、UI テストは main への push と、`ui-test` のラベルを付けた PR と、手で始めたときだけ回す。main で落ちたら、ワークフローが Issue を1つ立て、緑に戻ったら閉じる。その Issue は次の PR より先に直す

  **Why:** UI テストは画面が増えるほど延び、シミュレータの起動に数分かかる。PR のたびに回すと、画面がまだ揃わないうちから開発者もエージェントも十数分待っていた
