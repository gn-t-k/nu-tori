# nu-tori

## エージェントスキル

### Issue管理

Issueはこのリポジトリ（gn-t-k/nu-tori）のGitHub Issuesで管理する。詳細は `docs/agents/issue-tracker.md` を参照。

### triageラベル

標準の5ラベル（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）を使う。詳細は `docs/agents/triage-labels.md` を参照。

### ドメインドキュメント

単一コンテキスト構成：リポジトリ直下に `CONTEXT.md` と `docs/adr/` を1つずつ置く。詳細は `docs/agents/domain.md` を参照。

### スキルの管理

mattpocock/skills は [skills](https://skills.sh) CLIで `.agents/skills/` に入れ、`.claude/skills/` からシンボリックリンクしている。取り込んだスキルは `skills-lock.json` で管理する。

- クラウドセッションでは、開始時に `.claude/hooks/session-start.sh` が `npx skills update -p -y` を実行し、自動で最新版に更新する。
- ローカルでは `npx skills update -p -y` を手で実行する。
- 更新で上書きされるため、取り込んだスキルのファイルは直接編集しない。
