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
- 既存の表: 下の「既存の表の置き場」
- DB と移行の決まり: `server/AGENTS.md` の「DB」
- 表の形の考え方（値が無いことの表し方、イベントの表、時刻の列の名付け）: `.claude/skills/erd-design/references/table-design-rules.md`。種類ごとの表（サブセットの表）にするかは、同じフォルダの `phase3-representation.md` の「ステップ1」。行数や SQL が減ることは、表をまとめる理由にしない

## `/erd-design` の既定と違う前提

- 記録の DB はアカウントごとに1つ（ADR-0012）。1つの DB には1人分の記録だけが入るので、記録の表はアカウントを指す列を持たず、1人分として設計する。アカウントは D1 の認証の表にある

## 既存の表の置き場

パスは `server/` から数える。

- 食事の仕様（#188）の表の置き場: 食事とその削除の印は `src/meal/durable-object/meal-tables.ts`、写真（宣言、ファイルの受け取りと R2 から消した事実、宣言の削除の印）は同じフォルダの `meal-photo-tables.ts`、推定の出来事（予定・つなぎ・見送り・推定・試み・結果・完了・断念）は `src/estimation/durable-object/estimation-tables.ts`、料理は `src/dish/durable-object/dish-tables.ts`、材料と出どころのサブセットと栄養の値は `src/ingredient/durable-object/ingredient-tables.ts`。推定の出来事は記録の種類ではないので `src/estimation/` に別に置く。表を足すときは、親の表の束を import して外部キーを張る
- 食事を直す仕様（#332）の表の置き場: 当てた推定・推定の量・料理の名前と量の修正・比例の明細・料理が対象の予定のつなぎ・料理の削除の印は `dish-tables.ts`、材料の量の修正と材料の削除の印は `ingredient-tables.ts`、食事の時刻の修正は `meal-tables.ts`、予定の取り消しは `estimation-tables.ts`。表の束が互いを指す（料理 ↔ 材料、料理 ↔ 推定の出来事）ところは、指し返すほうの `references` に `(): AnySQLiteColumn =>` と型を書き、型の推論の循環を切る
- 文章と会話の仕様（#419）の表の置き場: 送った文章・読み分け・会話として送り直し・送り直し・会話として送り直しで消した食事の削除の印と、文章の食事のサブセット（文章の食事・推定が作った食事・推定した時刻）は `src/sent-text/durable-object/sent-text-tables.ts`、返事の流れの出来事（依頼・きっかけ・回数切れ・生成・試み・結果・作れなかった）は `src/reply/durable-object/reply-tables.ts`、返事と指し示す食事は `src/ai-utterance/durable-object/ai-utterance-tables.ts`。返事の流れは記録の種類ではないので、推定と同じく `src/reply/` に別に置く
- 目標を立てる仕様（#523）の表の置き場: 目標・減量と増量のサブセット・目標を閉じる・目標を決める要求の受け取りは `src/goal/durable-object/goal-tables.ts`、推定消費カロリーの推定と推定の始まりは `src/expenditure-estimate/durable-object/expenditure-estimate-tables.ts`、1日の目安と当たった上限と下限は `src/daily-guide/durable-object/daily-guide-tables.ts`。どの表も書き足すだけで、UPDATE も DELETE もしない。値が無いことは、サブセットの表に行が無いことで表す（維持の目標、閉じていない目標、始まりでない推定）。目標の向きは列に持たず、`src/goal/domain/compute-goal-direction.ts` が行の有無と体重の大小から出す
- 週の見直しと目標の経過の仕様（#613）の表の置き場: 週の見直しと見送りは `src/weekly-review/durable-object/weekly-review-tables.ts`、見直した推定は `expenditure-estimate-tables.ts`、見直した1日の目安は `daily-guide-tables.ts`、達成・期限の日の確定・期限後の維持の目標は `goal-tables.ts`。どの表も書き足すだけで、区分の値（見送りの理由、ずれの向き、主な理由）は種類の `domain/` の定数から `text({ enum })` で引く。DB の制約で保てない決まり（週の見直しは見送りか見直した推定のどちらか一方を持つ、など）は書く口が書く前に確かめる
- 課金の仕様（#647）の表の置き場: DO のサブスクリプション・取引・取り消しと戻し・請求の失敗と猶予・受け取り・無料体験なしは `src/subscription/durable-object/subscription-tables.ts`、推定の保留は `estimation-tables.ts`、返事のサブスクリプション切れの止めは `reply-tables.ts`、規約への同意は `src/terms-agreement/durable-object/terms-agreement-tables.ts`。D1 の購入者のトークン・案内・無料体験を使った Apple ID・テストユーザーは `src/subscription/d1/subscription-d1-tables.ts`。区分の値は `src/subscription/domain/subscription-transaction-fact.ts` の定数から `text({ enum })` で引く。判定（無料体験の最後の日、サブスクリプションの終わりなど）は `src/subscription/domain/` の純粋な関数で、表にもキャッシュの列にも持たない
