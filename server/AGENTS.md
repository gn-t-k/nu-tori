# server

nu-tori のサーバー。TypeScript で書き、Cloudflare で動かす（ADR-0011・0012）。

## 構成

- 構成の正本は `wrangler.jsonc`。上の階層が開発用で、本番は `env.production`。つなぎ（Durable Object、D1、R2 など）は環境に受け継がれないので、足すときは両方に書く
- `compatibility_date` は、`@cloudflare/vitest-plugin` が使う workerd が対応する日付までにする（それより後だと、テストの実行環境が起動しない）
- D1 と R2 は、`wrangler.jsonc` に書く前に、開発者に場所のヒント（`--location apac`）を付けて手で作ってもらう。デプロイのときの自動作成は場所のヒントを渡せず、CI が作ると CI の近くに置かれる。`wrangler.jsonc` には名前だけを書き、CI は名前で見つける
- Worker の型の宣言（`worker-configuration.d.ts`）は `wrangler types` が `wrangler.jsonc` から書き出す。コミットせず、`scripts/check server` が毎回書き出す
- Workers で動かないライブラリが要る処理が出たら、その部分だけ別の基盤に置く
- 秘密の値は `wrangler secret` に置く。足したら、`wrangler.jsonc` の `secrets.required`（使う環境に。本番だけの値は本番だけ）に名前を、`vitest.config.ts` にテストの値を書く。本番だけの秘密の値は `vitest.config.ts` に書かず、使うテストの中で `env` に足す（テストは開発用の設定で動くため）。GitHub Actions の秘密の値を足すときは `docs/agents/tooling.md` を読む

## 層

- 置き場: HTTP の受け口は `src/http/`、Durable Object は `src/durable-object/`、ドメイン層は `src/domain/`、認証（Better Auth と、Apple の API への入出力）は `src/auth/`、観測（Sentry の設定と、PostHog の API への入出力）は `src/observability/`
- 記録の種類ごとのまとまりは `src/<種類>/` に置き、中を層のサブフォルダ（`domain/`、`durable-object/`、`http/`）に分ける。置くもの: 種類の型、その種類だけにかかる受け付けの決まり、置き場の型と実装、受け口のスキーマと変換、その種類の同期のテスト。今は `src/weight-record/` と `src/account-settings/`。経路、認証、観測、`AccountDurableObject`、Durable Object の移行の並び、種類をまたぐ同期の仕組み（書き込みの当て方、同期の置き場の型と実装）は、今の層の置き場に残す
- 層は oxlint の `no-restricted-imports`（`.oxlintrc.json` の `overrides`）で守る。`src/domain/` と `src/<種類>/domain/` からは、受け口（`http`）、Durable Object（`durable-object`）、`cloudflare:*`、`hono` を import できない。import の文字列だけを見るので、別名の import を使い始めたら dependency-cruiser を考える
- 機能を第一の軸にする切り方（`src/<機能>/` の下に層を置く）を採らなかった理由は、[コードの置き方を縦に切るか（#153）](https://github.com/gn-t-k/nu-tori/issues/153) にある
- Durable Object のクラスは `instrumentDurableObjectWithSentry` で包み、Worker と同じ Sentry の設定（`src/observability/create-sentry-options.ts`）を渡す。包まないと、アラームの例外が Sentry に届かない
- ドメイン層は、実行基盤の型や API に触れない。ドメイン層が要る置き場と外への呼び出し（記録の置き場、写真の控え、LLM の提供元など）は、ドメイン層が型を定め、基盤に固有の層（Durable Object、D1・R2・LLM の提供元・Apple の API への入出力）がそれを実装する
- 1人の記録を読み書きするドメインの処理は、その人の Durable Object の中で動かす。Durable Object のクラスは、ドメイン層を呼ぶ入口（受け口の Worker から、アラームから）と、ドメイン層が定めた記録の置き場の実装と、ほかの基盤に固有の実装をドメイン層に渡すことだけを持つ薄い層にする
- HTTP の受け口は、記録を読み書きする要求なら、セッションを確かめ、回数の歯止めをかけてから、その人の Durable Object を呼ぶだけにする。まだセッションのないサインインと Apple のサーバー間通知は、受け口の Worker の認証で受ける。アカウントの削除は、受け口の Worker でドメイン層を呼ぶ。Durable Object の中身を消すときも、その Durable Object の入口を呼んで行う
- 受け口は、Durable Object を呼ぶたびにアカウント ID を渡す。Durable Object の中では、その呼び出しの Sentry の報告に user の ID として付ける
- 受け口のスキーマは要求の形だけを確かめる。受け付ける値の範囲はドメイン層で確かめる
- 想定した失敗（`docs/agents/languages/typescript.md` の「失敗の扱い」）を状態コードに直すのは受け口で行う
- Durable Object の RPC を越えたエラーには、`name`・独自のフィールド・`cause` が届き、`instanceof` は効かない（互換フラグ `enhanced_error_serialization`。`compatibility_date` が 2026-04-21 以降なら既定で有効）。`legacy_error_serialization` は足さない。足すと `name` が `"Error"` になり、独自のフィールドも消える

**Why:** ドメイン層を基盤から切り離しておくと、基盤を移るとき（出口は ADR-0012）に書き直すのが基盤に固有の層だけで済む。

## API

- REST＋OpenAPI。経路をスキーマつきで書き、書き出した OpenAPI の文書を `openapi.json` に置く。型の正本は経路のスキーマで、経路を変えたら `scripts/check server --fix` で書き出し直し（`scripts/check server` が最新かを確かめる）、`scripts/check ios --fix` でアプリのクライアントも生成し直す（`ios/AGENTS.md` の「API」）
- 経路には `operationId` を付ける。アプリで生成するクライアントのメソッドの名前になる
- 出回っている最も古い版のアプリとも動くようにする。API の変更は足すだけにし、壊す変更は新しい版のエンドポイントとして出す

## 同期の記録の種類の足し方

- 同期の共通の仕組み（帳簿）は `src/domain/sync-ledger/`。種類は帳簿に `RecordKind`（名前、書き込みを受け付けるかの決定、今の値を読む口）を渡す。冪等、控え、変更の並び、500 件の区切りは帳簿が持つので、種類に書き写さない
- 種類のまとまりを `src/<種類>/` に作り、種類、置き場、受け口の入口を置いたら、登録簿に1行ずつ足す（名前の順）: `domain/create-record-kinds.ts`、`domain/record-kind-stores.ts`、`durable-object/create-record-kind-stores.ts`、`http/sync-routes/http-record-kinds.ts`、`http/sync-routes/registered-write-schemas.ts`。ドメイン層は Durable Object と受け口を import できず、層ごとに登録簿が分かれるため5か所になる。受け口の2つは `RecordType` をキーにした表なので、足し忘れはコンパイルが止める。書き込みの `oneOf` の並びは表の順で決まるので、並びが変わるのを受け入れる
- 書き込みと変更の union（`SyncWrite`、`SyncChange`）、`RecordType`、受け口のスキーマ、`openapi.json` の `RecordKindName` の列挙は、登録簿から導く。手で足すのは、表の宣言の `text({ enum })`（`durable-object/sync-ledger-tables.ts`。型検査が足し忘れを止める）と、`scripts/check server --fix` での `openapi.json` の書き出し直し
- `RecordKindName` は端末が自分の登録簿と突き合わせるためのもので、応答の `kind` を解くのには使わない（`kind` は文字列のまま。知らない種類は端末が読み飛ばす）
- 種類の行（記録・削除の印・設定の変更）は、`decide` が返す `commit(receiptId)` の中で書く。控えの ID を帳簿しか作れない型にして、控えより先に書く形をコンパイルで止めるため

## 成分表のデータファイル

- 成分表のデータファイル（`src/domain/food-composition/food-composition-table.json`）は、文部科学省の本表の Excel から `scripts/build-food-composition-table.ts` が作る。手で書き換えず、成分表の版を上げるときや読み方を直したときに、`server/` で `pnpm exec tsx scripts/build-food-composition-table.ts` を回して作り直す。出典はファイルの `source`
- 栄養の項目の名前は `shared/nutrients.json`、成分表の列との対応は `src/domain/food-composition/nutrient-source-columns.ts`。項目を足すときは JSON に1行足し、対応を足して、データファイルを作り直す

## 認証

- 認証は Better Auth に任せる（ADR-0019）。Better Auth の表は D1 の中の認証の置き場に閉じ、ほかの表と Durable Object はアカウント ID だけを見る
- Better Auth の HTTP の口（`/api/auth/*`）は出さない。受け口の経路から Better Auth の `api` と `$context` を呼ぶ。経路をスキーマつきで OpenAPI の文書に載せ、Apple の識別子を返す口（アカウントの一覧など）を出さないため

## 身体データ

- 身体データと使い始める前の摂取エネルギーは、目標と推定消費量の計算に使ったら捨て、DB にもログにも残さない（ADR-0009）

## DB

- スキーマは素の SQLite で書く。表は Drizzle ORM で宣言して読み書きし、移行は手書きの SQL で持つ（ADR-0021）。Drizzle Kit は使わない
- Drizzle の宣言は、今の表の形に合わせて手で書く。記録の種類の表は `src/<種類>/durable-object/` に、帳簿の表と種類をまたぐ表は `src/durable-object/` に置き、全部を `durable-object-tables.ts` に集める。宣言は1ファイル1つの表の束を export する。移行を足すときは、SQL と宣言の両方を書く
- 置き場の実装のクエリは Drizzle で書く。`sql.raw()` と、自分で文字列を組み立てる SQL は使わない（`sql` のテンプレートに列を渡すのはよい）。DB から読んだ区分の文字列は、宣言の `text({ enum })` から導いた型で受け、読み戻す関数を書かない
- 宣言と移行がずれていないかは、`src/durable-object/durable-object-tables.test.ts` が、移行を当てた DB の実際の列（`pragma_table_info`）と宣言（`getTableConfig`）を比べて確かめる。比べる関数は `src/testing/find-table-declaration-mismatches.ts`（表と実際の列を渡すと、ずれの説明を返す。D1 の表にも使う）。表の宣言に無い表が DB にあっても落ちる
- 置き場のテストの行は `@praha/drizzle-factory` で作る（`src/durable-object/testing/durable-object-factory.ts`）。`create()` は Promise を返すので、テストで `await` して使い、同期の `transactionSync` の中では使わない。`drizzle(storage, { schema: durableObjectTables })` の `schema` を渡した db を factory に渡す
- D1 のスキーマの変更は、`d1-migrations/` の移行の SQL ファイルで行う
- Durable Object の中のスキーマの変更は、`durable-object-migrations/` に版つきの SQL ファイルを置き、`src/durable-object/durable-object-migrations.ts` の並びに足す。各 Durable Object が起動するときに、まだ当てていない版を、版の小さい順に自分の DB に当てる。並んだ PR の移行は版の大きいほうが先に当たることがあるので、並んで足す移行どうしは互いに頼らない形にする
- どちらの移行も足すだけにし、1つ前の版のコードでも動く形にする（下の「デプロイ」で、移行を当ててからコードを出すため）
- Durable Object のアラームは一度に1つしか張れない。アラームで動かすもの（推定など）は、予定を DB に持ち、いちばん早い予定にアラームを合わせる
- 記録に対しては、全員をまたぐ SQL は書けない。全員をまたぐ分析は、記録を書くときに分析用の出来事を PostHog に送って行う

## テスト

- テストは Workers の実行環境の中で回す
- D1 と Durable Object の中身は、テストのあいだ消えない。テストごとに新しい ID（`crypto.randomUUID()`）で書く

## デプロイ

- main へのマージごとに、開発用、本番の順にデプロイする。どちらも D1 の移行を当ててから Worker を出す。TestFlight の版は main から配られて本番につなぐので、main にある API は本番にも出ているようにする
- CI の API トークンの権限は、Workers の Admin（まだ無い Worker を作るのに要る）、D1 の編集、`nu-tori.app` のゾーンの Workers Routes の編集（独自ドメインを付け替えるのに要る）だけ。レガシーの Workers Scripts は使わない。CI にほかの製品を触らせるときは、開発者にトークンの権限を足してもらう
