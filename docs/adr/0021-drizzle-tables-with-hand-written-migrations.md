# 表は Drizzle で宣言して読み書きし、移行は手書きの SQL で持つ

サーバーの表（Durable Object の記録の表と、D1 の認証の表）は、Drizzle ORM で宣言し、クエリで読み書きする。行の型と表の宣言が1か所になり、置き場の adapter のテストで `@praha/drizzle-factory` から行を作れ、値を文字列に埋め込むインジェクションを構造で止められるため。移行は Drizzle Kit に任せず、今までどおり手書きの SQL で持つ（Durable Object は `durable-object-migrations/` の連番、D1 は `d1-migrations/`）。宣言と移行がずれていないかは、移行を当てた DB の列と宣言を比べるテストで確かめる。

## 検討した案

- 入れない（素の SQL を手で書き続ける）: 依存が増えない。行の型を手で写し、区分の文字列の読み戻しの罠（型を足しても型エラーにならず、DB から読んだときに落ちる）が残る。#103 の苦労（union・match・外部キーの順番）は Drizzle の有無で変わらず、同期の seam で解くが、それとは別に上の3つの利点を取った
- Drizzle Kit の移行まで使う: 0.45.3 の Durable Object 用の `migrate` は、最後に当てた移行より日時が新しいものだけを当てるので、あとから main に入った日時の古い移行が黙って飛ばされる。1.0 の rc は名前の集合で判断し、並べたブランチの衝突も確かめるが、rc のままで、`@praha/drizzle-factory`（peer は `drizzle-orm: 0.x`）とも型が合わない
- D1 だけ入れない: 認証の表の形の正本は Better Auth の設定で、Drizzle の宣言はその CLI が書き出すものになるが、同じ道具にそろえることを取った

## 起きること

- 表の宣言とクエリが adapter のコード全体に広がり、外すのは大仕事になる
- ADR-0012 の「スキーマは素の SQLite にする」は、移行が手書きの SQL のままなので保たれる。Turso へ移るときも、Drizzle は libSQL を扱う
- 移行を書くときは、表の宣言と SQL の両方を手で書く
- Durable Object の SQLite に Kit の `pull`・`push` は使えず、宣言と DB の一致を確かめる公式の手段は無い
- `@praha/drizzle-factory` の `create()` は Promise を返すので、同期の `transactionSync` の中では使えない（テストで `await` して使う）

## 選び直す条件

- Drizzle 1.0 が npm の `latest` になったとき（移行を Kit に任せるかを見直す）
- Drizzle のリリースが1年以上止まったとき

今の決定は、実装した PR で `server/AGENTS.md` の「DB」に書く。

根拠: 「[サーバーの表を Drizzle で扱うかを決める](https://github.com/gn-t-k/nu-tori/issues/150)」の解決コメント
