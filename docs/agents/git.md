# git の操作

- WIP コミットは、PR を出す前に工程ごとのコミットにまとめる
- 積み重ねた PR の前の PR を直したら、後ろのブランチに merge で取り込む。後ろのブランチを rebase すると、レビュー済みの差分とコメントの位置がずれるため

## 好みのレビュー

コード・テスト・依存を変えたブランチは、PR を出す前と、PR に push する前に、好みのレビューを通す。新しい文脈のサブエージェントに次を頼み、外れた箇所が0件になるまで直す。直したら、新しい文脈のサブエージェントでもう一度照らす。

1. `docs/agents/coding-style.md` と `docs/agents/testing.md`、変えたファイルの言語の `docs/agents/languages/<言語>.md`（あれば）を読む
2. `git fetch origin <マージ先のブランチ>` のあと、`git diff origin/<マージ先のブランチ>...HEAD` で差分を読む。判断に要るだけ、変更したファイルの前後や関係するファイルも読む
3. 差分で足した行と変えた行のすべてに、読んだ文書のすべてのルールを当てる。差分の外の既存のコードは対象にしない
4. 文書のルールからはっきり外れている箇所だけを、ファイル、行、当たったルールの見出し、直し方を添えて挙げる。文書に無い一般論や、ルールの読み方で判断が分かれるものは挙げない

0件になったら、PR の本文に、好みのレビューが0件になったことと、照らしたコミットを書く。push のたびに更新する。

## クラウドのセッションで GitHub を操作する

Claude Code on the web のセッション（`CLAUDE_CODE_REMOTE=true`）では、GitHub への通信がプロキシを通り、プロキシが認証を差し込む。

- `gh` は入っていない。要るときは `apt-get install -y gh` で入れる（見つからなければ先に `apt-get update`）
- 認証は、`GH_TOKEN` に仮の値を入れて `gh` を動かす（`GH_TOKEN=proxy-injected gh api ...`）。本物のトークンはプロキシが差し替えるので、PAT を環境変数に置かない
- GraphQL は PR 用の一部を除いて 403 になり、GraphQL を使う `gh issue ...` や `gh pr ...` は通らない。`gh api repos/<owner>/<repo>/...` の REST を使う
  - 読む: `gh api repos/gn-t-k/nu-tori/issues/<n>`、コメントは `.../issues/<n>/comments`
  - サブ Issue: `.../issues/<親>/sub_issues`（追加は `-X POST -F sub_issue_id=<子の DB ID>`）
  - 依存関係: `.../issues/<n>/dependencies/blocked_by`（追加は `-X POST -F issue_id=<ブロック元の DB ID>`）。すでに張られていると 422「already been taken」が返る
  - 担当者・ラベル・状態: `.../issues/<n>/assignees`、`.../issues/<n>/labels`、`-X PATCH .../issues/<n> -f state=closed`
- `mcp__github__*` のツールも使える。Issue、サブ Issue、コメント、PR は扱えるが、依存関係のツールは無いので `gh api` で張る
