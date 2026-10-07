# server

nu-tori のサーバー。TypeScript で書き、Cloudflare で動かす（ADR-0011・0012）。

## 構成

- 構成の正本は `wrangler.jsonc`。上の階層が開発用で、本番は `env.production`。つなぎ（Durable Object、D1、R2 など）は環境に受け継がれないので、足すときは両方に書く
- `compatibility_date` は、`@cloudflare/vitest-plugin` が使う workerd が対応する日付までにする（それより後だと、テストの実行環境が起動しない）
- D1 と R2 は、`wrangler.jsonc` に書く前に、開発者に場所のヒント（`--location apac`）を付けて手で作ってもらう。デプロイのときの自動作成は場所のヒントを渡せず、CI が作ると CI の近くに置かれる。`wrangler.jsonc` には名前だけを書き、CI は名前で見つける
- Worker の型の宣言（`worker-configuration.d.ts`）は `wrangler types` が `wrangler.jsonc` から書き出す。コミットせず、`scripts/check server` が毎回書き出す
- Workers で動かないライブラリが要る処理が出たら、その部分だけ別の基盤に置く
- 秘密の値は `wrangler secret` に置く。足したら、`wrangler.jsonc` の `secrets.required`（使う環境に。本番だけの値は本番だけ）に名前を、`vitest.config.ts` にテストの値を書く。本番だけの秘密の値は `vitest.config.ts` に書かず、使うテストの中で `env` に足す（テストは開発用の設定で動くため）。GitHub Actions の秘密の値を足すときは `docs/agents/tooling.md` を読む
- 推定の提供元（Anthropic）の API キーは、秘密の値 `ANTHROPIC_API_KEY` に置く。環境ごとの Anthropic のワークスペース（開発用は `nu-tori-development`、本番は `nu-tori-production`）のキーを、それぞれの環境に置く。`wrangler.jsonc` の `secrets.required` には両方の環境に書き、テストの値は `vitest.config.ts` にある（テストは提供元を偽物に差し替えるので、この値は本物に届かない）

## 確かめのジョブのためのサインインの口

- 開発用の環境で主な流れを確かめるジョブ（`docs/agents/tooling.md` の「CI」）は、Apple を通せないので、`POST /v1/e2e/sessions`（`src/http/e2e-session-routes/`）でサインインする。毎回新しいアカウントを作り、`sessionToken` と `accountId` を返す。OpenAPI の文書には載せない（アプリのクライアントに入れない）
- 本番で開くと誰でも入れてしまうので、次のすべてが揃ったときだけ開き、ほかは口が無いのと同じ 404 にする
  1. `SENTRY_ENVIRONMENT` が `development`（許可する名前を挙げる。本番や綴りの違う名前は閉じる）
  2. 秘密の値 `E2E_SIGN_IN_SECRET` が置かれていて、32 文字以上
  3. `x-e2e-sign-in-secret` ヘッダーがその秘密の値と一致する（一致しなければ 401。ハッシュにして定数時間で比べる）
- `E2E_SIGN_IN_SECRET` は開発用の Worker にだけ置き、本番の `wrangler.jsonc` と本番の Worker に書かない。置かなくても動き、口が閉じるだけなので、`secrets.required` には書かない（書くと、置くまで開発用のデプロイが失敗し、本番のデプロイも止まる）。型は `src/e2e-sign-in-secret.d.ts` で足す。本番の設定に名前を書いていないことは、`e2e-session-routes.test.ts` が `wrangler.jsonc` の文字列で確かめる
- 確かめる流れは `e2e/run-main-flow.ts`（Workers の実行環境のテストで、偽の提供元を差して通る）、実行の入口は `e2e/verify-development.ts`（Node で `pnpm exec tsx` で動かす）、送る写真と出典は `e2e/photos/`

## 層

- 置き場: HTTP の受け口は `src/http/`、Durable Object は `src/durable-object/`、ドメイン層は `src/domain/`、認証（Better Auth と、Apple の API への入出力）は `src/auth/`、観測（Sentry の設定と、PostHog の API への入出力）は `src/observability/`
- 記録の種類ごとのまとまりは `src/<種類>/` に置き、中を層のサブフォルダ（`domain/`、`durable-object/`、`http/`）に分ける。置くもの: 種類の型、その種類だけにかかる受け付けの決まり、置き場の型と実装、受け口のスキーマと変換、その種類の同期のテスト。今は `src/weight-record/`、`src/account-settings/`、`src/meal/`、`src/meal-estimation-status/`、`src/dish/`、`src/dish-estimation-status/`、`src/ingredient/`、`src/notice/`、`src/usual-weighing-time/`、`src/weight-trend/`。記録の種類ではない推定の出来事と推定の流れは `src/estimation/` に置く。経路、認証、観測、`AccountDurableObject`、Durable Object の移行の並び、種類をまたぐ同期の仕組み（書き込みの当て方、同期の置き場の型と実装）は、今の層の置き場に残す
- 層は oxlint の `no-restricted-imports`（`.oxlintrc.json` の `overrides`）で守る。`src/domain/` と `src/<種類>/domain/` からは、受け口（`http`）、Durable Object（`durable-object`）、`cloudflare:*`、`hono` を import できない。import の文字列だけを見るので、別名の import を使い始めたら dependency-cruiser を考える
- 機能を第一の軸にする切り方（`src/<機能>/` の下に層を置く）を採らなかった理由は、[コードの置き方を縦に切るか（#153）](https://github.com/gn-t-k/nu-tori/issues/153) にある
- Durable Object のクラスは `instrumentDurableObjectWithSentry` で包み、Worker と同じ Sentry の設定（`src/observability/create-sentry-options.ts`）を渡す。包まないと、アラームの例外が Sentry に届かない
- ドメイン層は、実行基盤の型や API に触れない。ドメイン層が要る置き場と外への呼び出し（記録の置き場、写真の控え、LLM の提供元など）は、ドメイン層が型を定め、基盤に固有の層（Durable Object、D1・R2・LLM の提供元・Apple の API への入出力）がそれを実装する
- 1人の記録を読み書きするドメインの処理は、その人の Durable Object の中で動かす。Durable Object のクラスは、ドメイン層を呼ぶ入口（受け口の Worker から、アラームから）と、ドメイン層が定めた記録の置き場の実装と、ほかの基盤に固有の実装をドメイン層に渡すことだけを持つ薄い層にする
- HTTP の受け口は、記録を読み書きする要求なら、セッションを確かめ、回数の歯止めをかけてから、その人の Durable Object を呼ぶだけにする。まだセッションのないサインインと Apple のサーバー間通知は、受け口の Worker の認証で受ける。アカウントの削除は、受け口の Worker でドメイン層を呼ぶ。Durable Object の中身を消すときも、その Durable Object の入口を呼んで行う
- 受け口は、Durable Object を呼ぶたびにアカウント ID を渡す。Durable Object の中では、その呼び出しの Sentry の報告に user の ID として付ける
- 受け口のスキーマは要求の形だけを確かめる。受け付ける値の範囲はドメイン層で確かめる
- 想定した失敗（`docs/agents/languages/typescript.md` の「失敗の扱い」）を状態コードに直すのは受け口で行う
- 失敗した段（R2、LLM の提供元の呼び出しなど）は、例外の `stage` の欄に持たせる。受け口の要求ごとのログ（`src/http/observe-request.ts`）が、例外の名前と一緒に出す
- Durable Object の RPC を越えたエラーには、`name`・独自のフィールド・`cause` が届き、`instanceof` は効かない（互換フラグ `enhanced_error_serialization`。`compatibility_date` が 2026-04-21 以降なら既定で有効）。`legacy_error_serialization` は足さない。足すと `name` が `"Error"` になり、独自のフィールドも消える

**Why:** ドメイン層を基盤から切り離しておくと、基盤を移るとき（出口は ADR-0012）に書き直すのが基盤に固有の層だけで済む。

## API

- REST＋OpenAPI。経路をスキーマつきで書き、書き出した OpenAPI の文書を `openapi.json` に置く。型の正本は経路のスキーマで、経路を変えたら `scripts/check server --fix` で書き出し直し（`scripts/check server` が最新かを確かめる）、`scripts/check ios --fix` でアプリのクライアントも生成し直す（`ios/AGENTS.md` の「API」）
- 経路には `operationId` を付ける。アプリで生成するクライアントのメソッドの名前になる
- 出回っている最も古い版のアプリとも動くようにする。API の変更は足すだけにし、壊す変更は新しい版のエンドポイントとして出す。最低バージョン（本番の `vars` の `MINIMUM_APP_BUILD`）より古いビルドは締め出すので、この「最も古い版」から外れる。締め出すかの線引きと上げる手順は `docs/agents/ios-release.md`
- 締め出しは受け口の入口（`src/http/reject-unsupported-app-build/`）で扱う。アプリが付けるビルド番号のヘッダー `X-App-Build` と、締め出したときの 426（本文は `{ "code": "app_build_unsupported" }`）は、経路のスキーマと OpenAPI の文書に載せない。`/v1` の経路は Apple のサーバー間通知を除いてすべて判定にかかるので、アプリから来ない経路を足すときは入口の外す経路に名前を足す

## 同期の記録の種類の足し方

- 同期の共通の仕組み（帳簿）は `src/domain/sync-ledger/`。種類は帳簿に `RecordKind`（名前、書き込みを受け付けるかの決定、今の値を読む口）を渡す。冪等、控え、変更の並び、500 件の区切りは帳簿が持つので、種類に書き写さない
- 種類のまとまりを `src/<種類>/` に作り、種類、置き場、受け口の入口を置いたら、登録簿に1行ずつ足す（名前の順）: `domain/create-record-kinds.ts`、`domain/record-kind-stores.ts`、`durable-object/create-record-kind-stores.ts`、`http/sync-routes/http-record-kinds.ts`。ドメイン層は Durable Object と受け口を import できず、層ごとに登録簿が分かれるため4か所になる。受け口の登録簿は `RecordType` をキーにした表なので、足し忘れはコンパイルが止める。書き込みのスキーマの並び（`registered-write-schemas.ts`）と、OpenAPI の値の部品は、この表から導く。書き込みの `oneOf` の並びは表の順で決まるので、並びが変わるのを受け入れる
- 書き込みと変更の union（`SyncWrite`、`SyncChange`）、`RecordType`、受け口のスキーマ、`openapi.json` の `RecordKindName` の列挙は、登録簿から導く。手で足すのは、表の宣言の `text({ enum })`（`durable-object/sync-ledger-tables.ts`。型検査が足し忘れを止める）と、`scripts/check server --fix` での `openapi.json` の書き出し直し
- 記録が消えたことの届け方は、ドメイン層の種類の `whenGone` の1か所で決める。削除の印を残す種類は `deletion_mark`、削除の印を持たず、ほかの記録から計算する種類（体重の傾向）は、記録が無くなったことも変更として届ける `absence`、消えない種類は `never`。取りに行く応答では、無くなったことは種類によらず `kind` が `<種類>_absence` で `record` が空の変更になる。帳簿は、`whenGone` と食い違う今の値（削除の印を持たない種類の削除の印、`absence` でない種類で変更の並びが指す記録も削除の印も無いこと）を、不具合として投げる。受け付けなかった書き込みの記録は、まだ作られていないことがあるので、どの種類でも無いことを返す
- 受け口の種類（`HttpRecordKind`）は、端末からの書き込み（スキーマと変換。サーバーだけが書く種類は `undefined`）、値のスキーマ（`recordSchema`）、値の変換（`toRecord`）を持つ。取りに行く変更の `record` は種類によらず文字列をキーにした値なので、値のスキーマを、種類の名前から作った名前（`weight_trend` なら `WeightTrendRecord`）の部品として `openapi.json` に書き出す。`kind` の文字列（値は種類の名前、削除の印は `<種類>_deletion`、無くなったことは `<種類>_absence`）は `to-change-body.ts` が付けるので、種類は書かない
- `RecordKindName` は端末が自分の登録簿と突き合わせるためのもので、応答の `kind` を解くのには使わない（`kind` は文字列のまま。知らない種類は端末が読み飛ばす）
- 種類の行（記録・削除の印・設定の変更）は、`decide` が返す `commit(receiptId)` の中で書く。控えの ID を帳簿しか作れない型にして、控えより先に書く形をコンパイルで止めるため
- 変更の並びの表（`record_changes`）に書くのは帳簿だけにする。種類と置き場は、変えた記録を帳簿に渡す
  - 書き込みが、自分の記録のほかに変える記録（食事を消すときの料理など）は、`decide` が返す `addedChanges` に載せる。帳簿は、`changedRecordId` の変更のあとに、控えと結ばずに並びの順で足す。載せられる種類は `RecordKind` の4つ目の型引数で宣言し、登録簿に無い種類は型検査が止める
  - ほかの種類の記録から計算する種類（体重の傾向、いつもの時刻）は、`RecordKind` の `follows` に元の種類の名前と `afterSourceApplied` を書く。帳簿は、元の種類の書き込みを当て（`applied`）、その変更を並びに載せたあとに、計算する種類を登録簿の順に呼ぶ。計算する種類は、書いたあとの記録を読んで自分の行を書き、変えた記録の ID を返す。元の種類は、計算する種類を知らない（`decide` で、書いたあとの記録をメモリの上で作り直さない）
  - 端末の書き込みの外（受け口の要求、アラーム）で記録を変えるときは、帳簿の `changeOutsideWrites(run)` の `run` の中で行を書き、変えた記録を `addChange` で渡す。`run` の書き込みと変更は1つのトランザクションに入り、変更には渡した順に通し番号が付く。帳簿は `createRecordLedger` で組む
- 書き込みを当てたときに PostHog に送る出来事（食事を受け取った、など）は、`decide` が返す `usageEvents` に載せる。帳簿は、その要求で初めて決めた書き込みの分だけを返し、同じ書き込みの ID が再び届いたときは返さない。送るかどうか（利用状況の設定）は、要求を当て終えたあとに `computeUsageEvents` が決める

## 推定

- 推定はアラームで進める。入口は `src/estimation/domain/advance-estimations.ts`: 待っている予定から推定を始め、次に試みる時刻が来た推定の試みを書いてから（`begin-estimation-attempts.ts`）、提供元を呼び（`run-estimation-attempt.ts`）、結果を書く（`record-estimation-attempt-outcome.ts`）。次に試みる時刻（待ちを広げる式と、試みの時間の上限）はドメイン層の `compute-next-estimation-attempt-at` が出し、`compute-next-alarm-at-except-leftover-photos.ts` もそれでアラームを合わせる
- 推定の予定と結果（予定・取り消し・見送り・推定・試み・結果・完了・断念）は、推定の書き込みの口（`src/estimation/domain/write-estimation-events.ts`）を通して書く。書く置き場はこの口にしか渡らず、口が書く前とあとの推定の状態を比べて変わった食事・料理にだけ推定の状態の変更を足すので、書く場所では足さない
- 予定と推定の対象は、食事（写真の推定）か料理（名前を直した・料理を足したときの推定し直し。`EstimationTarget`）。料理が対象の推定は、料理の今の値を ① に渡し、終わったら `apply-dish-estimation.ts` が当てるかを決めて当てる。回数・見送り・やり直し・アラームは食事が対象の推定と同じ流れに載る
- 推定の回数は、アカウントごとに1日 `maximumDailyEstimations`（30）まで。`beginEstimationAttempts` が、予定から推定を始める前に、予定の数える日（`counted_on`）の `estimations` を数え、上限なら見送る（`estimation_deferrals`、次の日の 0:00 の予定とつなぎ、PostHog の `estimation_deferred`）。次の日の 0:00 は、ユーザーの最新のタイムゾーン（読めなければ食事を送ったときのもの）で `computeNextDayStart` が出し、その日の分に数える。日ごとの回数の行は持たず、食事を消しても推定の行は残るので回数は戻らない。テストは `src/estimation/http/testing/insert-counted-estimations.ts` で、食事につながらない推定を書いて回数を満たす
- 提供元（LLM）は、ドメイン層の型 `EstimationProvider`（`src/estimation/domain/estimation-provider.ts`）を、`src/estimation/durable-object/create-estimation-provider/` が作る。Durable Object は推定のたびにここから得る。本物は Anthropic の API（`@anthropic-ai/sdk`。再試行は SDK でなくドメイン層が持つので切る）で、`create-anthropic-estimation-provider.ts` が組む。モデルは Claude Sonnet 5（`request-structured-output.ts` の1か所）、思考は `thinking: { type: "disabled" }` で切り、`metadata.user_id` にアカウント ID の SHA-256 を入れ、構造化出力（`output_config.format`）で答えさせる。呼び出し1回の時間の上限は ① が 90 秒、② が 60 秒（試み全体の 3 分の中に収まる）。HTTP 400 は 400 の失敗、時間切れは時間切れの失敗、そのほかの SDK のエラーは提供元のエラー（`errorType` は応答のエラーの種類、無ければ `http_<状態コード>`、つなげなければ `connection_error`）、構造化出力が読めない・出力の上限で切れた・答えなかったは読めない応答の失敗（使ったトークンつき）にする。提供元の応答のテキストは残さない。差し替えの口はここ1つにし、テストは同じフォルダの mock で偽物に差し替える（料理あり・料理なし・確かめに通らない・答える前に待つは `mockCreateEstimationProviderOk`、エラー・400・時間切れ・② だけ落ちるは `mockCreateEstimationProviderError`）。提供元そのものの要求の組み立てと応答の読み取りは、Anthropic の API の手前（SDK の `fetch`）を差し替えて確かめる（`testing/stub-anthropic-api.ts`）
- 提供元の失敗と、確かめに通らない応答は、試みの結果（`estimation_attempt_results.result`）にする。R2 と成分表の段で止まったら投げ、試みを結果の無いまま残して、途中で止まった試みとして数える
- アラームの中は受け口の要求ごとのログを通らないので、アラームが呼び出しごとに `route: "alarm"` のログを出す（試みごとの結果・失敗した段・提供元のエラーの種類）
- 推定のテストは、`src/estimation/http/testing/use-fake-clock.ts` で Date だけを先の時刻にして、アラームがひとりでに動かないようにし、`runDurableObjectAlarm` で動かす。やり直しは時計を進めてから動かす

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
- 食事の仕様（#188）の表の置き場: 食事とその削除の印は `src/meal/durable-object/meal-tables.ts`、写真（宣言、ファイルの受け取りと R2 から消した事実、宣言の削除の印）は同じフォルダの `meal-photo-tables.ts`、推定の出来事（予定・つなぎ・見送り・推定・試み・結果・完了・断念）は `src/estimation/durable-object/estimation-tables.ts`、料理は `src/dish/durable-object/dish-tables.ts`、材料と出どころのサブセットと栄養の値は `src/ingredient/durable-object/ingredient-tables.ts`。推定の出来事は記録の種類ではないので `src/estimation/` に別に置く。表を足すときは、親の表の束を import して外部キーを張る
- 食事を直す仕様（#332）の表の置き場: 当てた推定・推定の量・料理の名前と量の修正・比例の明細・料理が対象の予定のつなぎ・料理の削除の印は `dish-tables.ts`、材料の量の修正と材料の削除の印は `ingredient-tables.ts`、食事の時刻の修正は `meal-tables.ts`、予定の取り消しは `estimation-tables.ts`。表の束が互いを指す（料理 ↔ 材料、料理 ↔ 推定の出来事）ところは、指し返すほうの `references` に `(): AnySQLiteColumn =>` と型を書き、型の推論の循環を切る
- 置き場の実装のクエリは Drizzle で書く。`sql.raw()` と、自分で文字列を組み立てる SQL は使わない（`sql` のテンプレートに列を渡すのはよい）。DB から読んだ区分の文字列は、宣言の `text({ enum })` から導いた型で受け、読み戻す関数を書かない
- 宣言と移行がずれていないかは、`src/durable-object/durable-object-tables.test.ts` が、移行を当てた DB の実際の列（`pragma_table_info`）と宣言（`getTableConfig`）を比べて確かめる。比べる関数は `src/testing/find-table-declaration-mismatches.ts`（表と実際の列を渡すと、ずれの説明を返す。D1 の表にも使う）。表の宣言に無い表が DB にあっても落ちる
- 置き場のテストの行は `@praha/drizzle-factory` で作る（`src/durable-object/testing/durable-object-factory.ts`）。`create()` は Promise を返すので、テストで `await` して使い、同期の `transactionSync` の中では使わない。`drizzle(storage, { schema: durableObjectTables })` の `schema` を渡した db を factory に渡す
- D1 のスキーマの変更は、`d1-migrations/` の移行の SQL ファイルで行う
- Durable Object の中のスキーマの変更は、`durable-object-migrations/` に版つきの SQL ファイルを置き、`src/durable-object/durable-object-migrations.ts` の並びに足す。各 Durable Object が起動するときに、まだ当てていない版を、版の小さい順に自分の DB に当てる。並んだ PR の移行は版の大きいほうが先に当たることがあるので、並んで足す移行どうしは互いに頼らない形にする
- どちらの移行も足すだけにし、1つ前の版のコードでも動く形にする（下の「デプロイ」で、移行を当ててからコードを出すため）
- あとで `meals`・`dishes`・`ingredients` の子の表を足すとき、自分の削除の印を持たない子（文章の食事のサブセット、料理が対象の予定のつなぎ、料理を作った推定など）は `ON DELETE CASCADE` にする。1つ前の版のコードは、あとで足した子を知らずに親を消すので、NO ACTION だと食事を消す書き込みが外部キーの違反で送り直され続ける
- 控えだけを指す修正の行（時刻・名前・量の修正）は、外部キーで記録を指さず、料理・食事を消す口が、その記録を書き換えた控えから探して消す
- 索引は、同期の要求ごとに走る引き方に加え、アラームや推定の開始ごと、記録を受け取るごとに走る引き方にも置く。行が食事の数ほど増え続ける表（予定・推定・試み・料理・材料など）が対象になる。引く道が無いもの（控えから削除の印を引く）や、索引が効かない引き方（待っている予定を、推定も見送りも無いことで出す）には置かない
- Durable Object のアラームは一度に1つしか張れない。アラームで動かすもの（推定など）は、予定を DB に持ち、いちばん早い予定にアラームを合わせる
  - いちばん早い時刻は `src/domain/compute-next-alarm-at.ts` が表から出し、送る要求と写真の要求の入口で張る。写真の控えの消し残しを除いた時刻は `src/domain/compute-next-alarm-at-except-leftover-photos.ts` が出し、消し直しに失敗したアラームはこちらで張り直す（今に張り直さず、Cloudflare のアラームのやり直しに任せる）。アラームで動かすものを足すときは、その時刻を後者に足す（足さないと、入口で張り直したときに遅い時刻で上書きする）
  - アラーム1回分（推定を進め、写真の控えの消し残しを消し、次に張る時刻と報告するエラーを決める）は `src/domain/run-account-alarm.ts` に置く。Durable Object の `alarm()` は、返った時刻に張り、Sentry・PostHog・ログに出し、エラーを投げるだけにする
  - アラームの中のアカウント ID は `ctx.id.name`（`idFromName` で付けた名前）から得る。テストの実行環境でも、張ったアラームはひとりでに動くので、アラームの結果を確かめるテストは `runDurableObjectAlarm` で動かしたうえで `vi.waitFor` で待つ
- 記録に対しては、全員をまたぐ SQL は書けない。全員をまたぐ分析は、記録を書くときに分析用の出来事を PostHog に送って行う

## テスト

- テストは Workers の実行環境の中で回す
- D1 と Durable Object の中身は、テストのあいだ消えない。テストごとに新しい ID（`generateRecordId()`）で書く

## デプロイ

- main へのマージごとに、開発用、本番の順にデプロイする。どちらも D1 の移行を当ててから Worker を出す。TestFlight の版は main から配られて本番につなぐので、main にある API は本番にも出ているようにする
- 本番の前に、浅い確認（開発用に出した Worker が応答し、D1 を読めるかだけを見る）を挟む。`deploy.yml` の `shallow-check` が開発用の `GET /health`（`src/http/health-routes/`）を呼び、本番のデプロイは、開発用のデプロイと浅い確認の両方が通ったときだけ動く。主な流れを通す `verify-development` は本番を待たせない
- `GET /health` は認証なしで呼べるので、本文に記録の中身もアカウントの情報も入れない（ADR-0017）。アプリの API の版（`/v1`）の外に置き、OpenAPI の文書に載せず、強制アップデートの判定にもかけない
- 出したあとに壊れたら、前の版のコードに戻さず、直した新しい版を出す（roll forward）。移行は足すだけでも、既存の列に新しい値（記録の種類 `meal` など）が入るので、前の版のコードがそれを読めず、そのアカウントの取りに行く要求が失敗し続けうる
  - 例外は、依存だけを上げた PR の revert。依存だけの PR は DB に書く値を変えないので、前の版のコードに戻しても読めない値が無い。戻し方は `docs/agents/dependencies.md` の「壊れたときの戻し方」
- CI の API トークンの権限は、Workers の Admin（まだ無い Worker を作るのに要る）、D1 の編集、`nu-tori.app` のゾーンの Workers Routes の編集（独自ドメインを付け替えるのに要る）だけ。レガシーの Workers Scripts は使わない。CI にほかの製品を触らせるときは、開発者にトークンの権限を足してもらう
