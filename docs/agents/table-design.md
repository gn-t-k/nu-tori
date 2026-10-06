# 表の設計

記録の表（Durable Object の SQLite と D1）を足す・変えるときの進め方。

## 時機と置き場

- 表は、仕様ごとに、その仕様で増える・変わる分だけを設計する。仕様で表が増える・変わるなら、`/to-spec` を呼ぶ前に、ユーザーに `/erd-design` を範囲「差分」で呼ぶよう促す。仕様の範囲は「[仕様の分け方](https://github.com/gn-t-k/nu-tori/issues/91)」の解決コメント
- `/erd-design` の出力ファイルは `.scratch/erd-design/<仕様の名前>.md` に置く（コミットしない作業のファイル）。決まった ERD と設計判断は、仕様の Issue の Implementation Decisions の「Schema changes」に書く。そのあとの正本の移り方は `docs/agents/decisions.md`

## 要件として読むもの

- 概念モデル: `docs/ui-design/0001-first-release/03-concept-model.md`
- 用語: `GLOSSARY.md`
- 同期の約束: 「[端末とサーバーの同期とオフライン時の振る舞い](https://github.com/gn-t-k/nu-tori/issues/26)」の追記の「同期」
- その仕様の決定チケット: 「仕様の分け方」の解決コメントの「仕様ごとに読む決定チケット」
- 既存の表と、DB と移行の決まり: `server/AGENTS.md` の「DB」
- 表の形の考え方（値が無いことの表し方、イベントの表、時刻の列の名付け）: `.claude/skills/erd-design/references/table-design-rules.md`。種類ごとの表（サブセットの表）にするかは、同じフォルダの `phase3-representation.md` の「ステップ1」。行数や SQL が減ることは、表をまとめる理由にしない

## `/erd-design` の既定と違う前提

- 記録の DB はアカウントごとに1つ（ADR-0012）。1つの DB には1人分の記録だけが入るので、記録の表はアカウントを指す列を持たず、1人分として設計する。アカウントは D1 の認証の表にある
