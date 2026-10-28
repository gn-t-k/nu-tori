# サーバーの同期の帳簿と記録の種類

パスは `server/` から数える。

- 同期の共通の仕組み（帳簿）は `src/domain/sync-ledger/`。種類は帳簿に `RecordKind`（名前、書き込みを受け付けるかの決定、今の値を読む口）を渡す。冪等、控え、変更の並び、500 件の区切りは帳簿が持つので、種類に書き写さない
- 種類の名前を書くのは、名前の一覧（`domain/record-types.ts`）の1か所だけにする。何も import しない定数で、`RecordType` と、帳簿の表の `text({ enum })`（`durable-object/sync-ledger-tables.ts`）がここから引く。`record_type` の列は TEXT で、SQL に値の並びを書いていないので、種類を足しても移行は要らない
- 種類を足すときは、一覧に名前を足し、種類のまとまりを `src/<種類>/` に作って、種類、置き場、受け口の入口を置き、登録簿に1行ずつ足す（どれも名前の順）: `domain/create-record-kinds.ts`、`domain/record-kind-stores.ts`、`durable-object/create-record-kind-stores.ts`、`http/sync-routes/http-record-kinds.ts`。ドメイン層は Durable Object と受け口を import できず、層ごとに登録簿が分かれるため4か所になる。一覧に足した名前が種類の登録簿（`create-record-kinds.ts`）か受け口の登録簿（`RecordType` をキーにした表）に無いと、型検査が止める。一覧に無い名前の種類も止める。書き込みのスキーマの並び（`registered-write-schemas.ts`）と、OpenAPI の値の部品は、受け口の登録簿から導く。書き込みの `oneOf` の並びは表の順で決まるので、並びが変わるのを受け入れる
  - 種類のまとまりに置くファイル: `domain/` に値の型、置き場の型、種類（`create-<種類>-kind.ts`）、端末が書く種類は書き込みの型。`durable-object/` に表の宣言と置き場の実装。`http/` に受け口の入口（`<種類>-http-kind.ts`）の1つ
  - サーバーだけが書く種類は、`createServerOnlyKind`（`domain/sync-ledger/create-server-only-kind/`）で作る。渡すのは、名前、`whenGone`、今の値を探す `find`（無ければ `undefined`）。記録の ID が親の記録の ID で、親と一緒に消える種類（推定の状態、料理ごとの推定の状態）は、`whenGone` を `deletion_mark` にして親（あるか、削除の印があるか）を渡す。ほかの種類から計算する種類は `follows` も渡す
- 書き込みと変更の union（`SyncWrite`、`SyncChange`）、受け口のスキーマ、`openapi.json` の `RecordKindName` の列挙は、登録簿から導く。最後に `scripts/check server --fix` で `openapi.json` を書き出し直す
- 記録が消えたことの届け方は、ドメイン層の種類の `whenGone` の1か所で決める。削除の印を残す種類は `deletion_mark`、削除の印を持たず、ほかの記録から計算する種類（体重の傾向）は、記録が無くなったことも変更として届ける `absence`、消えない種類は `never`。取りに行く応答では、無くなったことは種類によらず `kind` が `<種類>_absence` で `record` が空の変更になる。帳簿は、`whenGone` と食い違う今の値（削除の印を持たない種類の削除の印、`absence` でない種類で変更の並びが指す記録も削除の印も無いこと）を、不具合として投げる。受け付けなかった書き込みの記録は、まだ作られていないことがあるので、どの種類でも無いことを返す
- 受け口の種類（`HttpRecordKind`）は、端末からの書き込み（スキーマと変換。サーバーだけが書く種類は `undefined`）、値のスキーマ（`recordSchema`）、値の変換（`toRecord`）を持つ。スキーマと変換は、種類の受け口の入口（`src/<種類>/http/<種類>-http-kind.ts`）の1ファイルに書き、ファイルに分けない。取りに行く変更の `record` は種類によらず文字列をキーにした値なので、値のスキーマを、種類の名前から作った名前（`weight_trend` なら `WeightTrendRecord`）の部品として `openapi.json` に書き出す。`kind` の文字列（値は種類の名前、削除の印は `<種類>_deletion`、無くなったことは `<種類>_absence`）は `to-change-body.ts` が付けるので、種類は書かない
- `RecordKindName` は端末が自分の登録簿と突き合わせるためのもので、応答の `kind` を解くのには使わない（`kind` は文字列のまま。知らない種類は端末が読み飛ばす）
- `decide` は、受け付けるかの決定（`WriteDecision`。当てる `applied`、今の値と同じ `unchanged`、捨てる `ignored_duplicate`・`ignored_tombstone`・`kept_corrected`、受け付けない `rejected`）を返す。控えに載せる結果、書き込みの記録の変更を並びに載せるか、後に続く種類を走らせるかは、帳簿が決定から決め、種類は書かない。削除の印に当たって捨てた書き込みは、いつも削除の印を並びに載せ直す（削除の印を取り終えた端末に、作り直した記録を残させないため）
- 種類の行（記録・削除の印・設定の変更）は、`decide` が返す `commit(receiptId)` の中で書く。控えの ID を帳簿しか作れない型にして、控えより先に書く形をコンパイルで止めるため
- 変更の並びの表（`record_changes`）に書くのは帳簿だけにする。種類と置き場は、変えた記録を帳簿に渡す
  - 書き込みが、自分の記録のほかに変える記録（食事を消すときの料理など）は、`decide` が返す `addedChanges` に載せる。帳簿は、書き込みの記録の変更のあとに、控えと結ばずに並びの順で足す。`commit` の中で変えた記録が分かる場合（推定の書き込みの口が足す推定の状態の変更）は、`commit` に渡る `addChange` で足す。帳簿は、`addedChanges` のあとに足した順で載せ、同じ記録の変更を最初の1つにまとめる。載せられる種類は `RecordKind` の4つ目の型引数で宣言し、登録簿に無い種類は型検査が止める
  - ほかの種類の記録から計算する種類（体重の傾向、いつもの時刻）は、`RecordKind` の `follows` に元の種類の名前と `afterSourceApplied` を書く。帳簿は、元の種類の書き込みを当て（`applied`）、その変更を並びに載せたあとに、計算する種類を登録簿の順に呼ぶ。計算する種類は、書いたあとの記録を読んで自分の行を書き、変えた記録の ID を返す。元の種類は、計算する種類を知らない（`decide` で、書いたあとの記録をメモリの上で作り直さない）
  - 端末の書き込みの外（受け口の要求、アラーム）で記録を変えるときは、記録の変化を書く入口（`src/domain/record-change-writer.ts` の `RecordChangeWriter`。Durable Object では `durable-object/create-record-change-writer/` が組み、中身は `domain/write-record-changes-to-stores.ts`）に `run` を渡し、その中で行を書いて、変えた記録を `addChange` で渡す。`run` の書き込みと変更は1つのトランザクションに入り、変更には渡した順に通し番号が付く。推定の予定と結果は `estimation`、返事の流れの出来事は `reply` で書き、変わった状態の変更は入口が `run` のあとに足す。流れ（推定・返事・読み分け・写真の受け取り）は帳簿を組まず、入口と、自分が読み書きする置き場だけを受け取る
- 書き込みを当てたときに PostHog に送る出来事（食事を受け取った、など）は、`decide` が返す `usageEvents` に載せる。帳簿は、その要求で初めて決めた書き込みの分だけを返し、同じ書き込みの ID が再び届いたときは返さない。送るかどうか（利用状況の設定）は、要求を当て終えたあとの設定で Durable Object が送る前に決める（`server/AGENTS.md` の「層」）
