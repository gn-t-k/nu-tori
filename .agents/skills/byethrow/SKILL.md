---
name: byethrow
description: byethrow（@praha/byethrow の Result）と、その周り（@praha/error-factory、@praha/byethrow-testing、@praha/byethrow-oxlint）の docs を引く。サーバーの TypeScript で Result を書く・直すとき、API や書き方を確かめるときに使う。
allowed-tools: Read, Grep, Glob, Bash(pnpm --dir server exec byethrow-docs:*)
---

# byethrow の docs を引く

docs は `server/` の依存の `@praha/byethrow-docs` に入っている。版は `server/package.json` の `@praha/byethrow` と揃う。

- Markdown は `server/node_modules/@praha/byethrow-docs/docs/` の下にある（`guide/`: 使い方と良い書き方、`api/`: 関数と型、`examples/`: 例）。Read・Grep・Glob で読んでよい
- 無ければ `scripts/check server` か `pnpm --dir server install` で依存を入れる

このリポジトリでの書き方は `docs/agents/languages/typescript.md` の「失敗の扱い」と「関数は処理の流れで分ける」が正。docs の例と違うところ（名前空間は `Result` ではなく `R`、分岐は switch ではなく ts-pattern の `match(...).exhaustive()`、自分たちのエラーは `instanceof` ではなく `name` で見分ける）は、そちらに従う。

## CLI

リポジトリのルートから呼ぶ。

```bash
# 一覧（--query で絞る）
pnpm --dir server exec byethrow-docs list
pnpm --dir server exec byethrow-docs list --query "pattern matching"

# 探す（既定で5件。--limit で変える）
pnpm --dir server exec byethrow-docs search "andThen async"
pnpm --dir server exec byethrow-docs search "custom error" --limit 10

# 目次（list・search が返した path をそのまま渡す）
pnpm --dir server exec byethrow-docs toc <path>
```
