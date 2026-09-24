# nu-tori

## エージェントスキル

### Issue管理

Issueはこのリポジトリ（gn-t-k/nu-tori）のGitHub Issuesで管理する。詳細は `docs/agents/issue-tracker.md` を参照。

### triageラベル

標準の5ラベル（`needs-triage`、`needs-info`、`ready-for-agent`、`ready-for-human`、`wontfix`）を使う。詳細は `docs/agents/triage-labels.md` を参照。

### ドメインドキュメント

単一コンテキスト構成：リポジトリ直下に `CONTEXT.md` と `docs/adr/` を1つずつ置く。詳細は `docs/agents/domain.md` を参照。

### デザイン

UI を実装・変更するときは、リポジトリ直下の `DESIGN.md`（見た目のトークンとガードレール）があれば従う。`docs/ui-design/` は凍結済みの設計記録で、現在の用語と決定は `CONTEXT.md` と `docs/adr/` が持つ。

### スキルの管理

mattpocock/skills は `skills-lock.json` で管理し、`.claude/hooks/session-start.sh` で自動更新している。更新で上書きされるため、`.agents/skills/` 配下は直接編集しない。

### 進め方

- ユーザーへの返事と、リポジトリに置く文書は日本語で書く
- 比べるものや流れは、表より図で見せる
- 文書には現在の状態だけを書く。経緯はコミットメッセージと PR に書く
- UI や振る舞いの選択肢を尋ねるときは、`/prototype` で見比べられるものを先に作る
- 工程のゲートや引き継ぎなどの大きな確認は、新しい文脈のサブエージェントにその工程のスキルの観点でレビューさせ、必ず直すものが0件になるまで直す

### git

コミット、PR の作成、ブランチの更新をするときは `docs/agents/git.md` を読む。
