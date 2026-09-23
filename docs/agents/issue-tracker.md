# Issue管理：GitHub

このリポジトリのIssueと仕様はGitHub Issuesで管理する。操作にはすべて `gh` CLIを使う。

## 運用ルール

- **Issueを作る**：`gh issue create --title "..." --body "..."`。本文が複数行になるときはヒアドキュメントを使う。
- **Issueを読む**：`gh issue view <番号> --comments`。コメントは `jq` で絞り込み、ラベルもあわせて取得する。
- **Issueを一覧する**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`。必要に応じて `--label` と `--state` で絞り込む。
- **Issueにコメントする**：`gh issue comment <番号> --body "..."`
- **ラベルを付ける／外す**：`gh issue edit <番号> --add-label "..."` ／ `--remove-label "..."`
- **クローズする**：`gh issue close <番号> --comment "..."`

対象リポジトリは `git remote -v` から判断する。クローン内で実行すれば `gh` が自動で判断する。

## PRをtriage対象にするか

**PRを要望の受付窓口として扱う：いいえ。**（外部からのPRを機能要望として扱う場合は「はい」にする。`/triage` がこの設定を読む）

「はい」の場合、PRもIssueと同じラベルと状態で扱い、対応する `gh pr` コマンドを使う。

- **PRを読む**：`gh pr view <番号> --comments`、差分は `gh pr diff <番号>`。
- **triage対象の外部PRを一覧する**：`gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments` を実行し、`authorAssociation` が `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR`、`NONE` のものだけ残す（`OWNER`／`MEMBER`／`COLLABORATOR` は除く）。
- **コメント／ラベル／クローズ**：`gh pr comment`、`gh pr edit --add-label`／`--remove-label`、`gh pr close`。

GitHubではIssueとPRが同じ番号空間を共有するため、`#42` だけではどちらか分からない。まず `gh pr view 42` を試し、だめなら `gh issue view 42` で確認する。

## スキルが「Issue管理に登録する」と言ったとき

GitHub Issueを作る。

## スキルが「該当チケットを取得する」と言ったとき

`gh issue view <番号> --comments` を実行する。

## wayfinderの操作

`/wayfinder` が使う。**マップ**は1つのIssueで、その**子**Issueがチケットになる。

- **マップ**：`wayfinder:map` ラベルを付けた1つのIssue。本文にメモ／これまでの決定事項／未解明事項を持つ。`gh issue create --label wayfinder:map`。
- **子チケット**：GitHubのサブIssueとしてマップに紐づけたIssue（サブIssueのエンドポイントに `gh api` で登録）。サブIssueが使えない場合は、マップ本文のタスクリストに子を追加し、子の本文の先頭に `Part of #<マップ>` と書く。ラベルは `wayfinder:<種類>`（`research`／`prototype`／`grilling`／`task`）。着手したら担当者を作業中の開発者にする。
- **ブロック関係**：GitHubの**ネイティブなIssue依存関係**を使う（UIでも見える正式な表現）。`gh api --method POST repos/<owner>/<repo>/issues/<子>/dependencies/blocked_by -F issue_id=<ブロック元のDB ID>` で依存を追加する。`<ブロック元のDB ID>` はブロック元Issueの数値の**データベースID**（`gh api repos/<owner>/<repo>/issues/<n> --jq .id` で取得。`#番号` や `node_id` ではない）。GitHubは `issue_dependencies_summary.blocked_by`（未解決のブロック元の数。これが実際の関門）を返す。依存関係が使えない場合は、子の本文の先頭に `Blocked by: #<n>, #<n>` と書く。ブロック元がすべてクローズされたらブロック解除とみなす。
- **着手可能なチケットの探し方**：マップの未クローズの子を一覧し（`gh issue list --state open` をマップのサブIssue／タスクリストに限定）、未解決のブロック元があるもの（`issue_dependencies_summary.blocked_by > 0`、または `Blocked by` 行に未クローズのIssueがあるもの）と担当者がいるものを除く。残ったうちマップ上で最初のものを選ぶ。
- **着手宣言**：`gh issue edit <n> --add-assignee @me`。セッションで最初に行う書き込みにする。
- **解決**：`gh issue comment <n> --body "<回答>"`、続けて `gh issue close <n>`。最後にマップの「これまでの決定事項」に要点とリンクを追記する。
