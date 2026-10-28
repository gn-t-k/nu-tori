# server

nu-tori のサーバー。TypeScript で書き、Cloudflare で動かす（ADR-0011・0012）。

## 構成

- 構成の正本は `wrangler.jsonc`。上の階層が開発用で、本番は `env.production`。つなぎ（Durable Object、D1、R2 など）は環境に受け継がれないので、足すときは両方に書く
- `compatibility_date` は、`@cloudflare/vitest-plugin` が使う workerd が対応する日付までにする（それより後だと、テストの実行環境が起動しない）
- D1 と R2 は、`wrangler.jsonc` に書く前に、開発者に場所のヒント（`--location apac`）を付けて手で作ってもらう。デプロイのときの自動作成は場所のヒントを渡せず、CI が作ると CI の近くに置かれる。`wrangler.jsonc` には名前だけを書き、CI は名前で見つける
- Worker の型の宣言（`worker-configuration.d.ts`）は `wrangler types` が `wrangler.jsonc` から書き出す。コミットせず、`scripts/check server` が毎回書き出す
- Workers で動かないライブラリが要る処理が出たら、その部分だけ別の基盤に置く
- 秘密の値は `wrangler secret` に置く。足したら、`wrangler.jsonc` の `secrets.required`（使う環境に。本番だけの値は本番だけ）に名前を、`vitest.config.ts` にテストの値を書く。本番だけの秘密の値は `vitest.config.ts` に書かず、使うテストの中で `env` に足す（テストは開発用の設定で動くため）。GitHub Actions の秘密の値を足すときは `docs/agents/tooling.md` を読む
- 推定・読み分け・返事（LLM の提供元、その鍵と費用の上限、Workers AI と AI Gateway、成分表のデータファイル）に触るときは、`docs/agents/server-llm.md` を読む

## 層

- 置き場: HTTP の受け口は `src/http/`、Durable Object は `src/durable-object/`、ドメイン層は `src/domain/`、認証（Better Auth と、Apple の API への入出力）は `src/auth/`、観測（Sentry の設定と、PostHog の API への入出力）は `src/observability/`、App Store の署名つきの値を確かめて読む入口（根の Apple Root CA - G3 と、テストで鎖と JWS を作る道具の `testing/`）は `src/app-store/`。受け口は根を `src/app-store/app-store-root-certificate/` から読み、受け口のテストは同じフォルダの `.mock.ts` で、作った鎖の根に差し替える
- 記録の種類ごとのまとまりは `src/<種類>/` に置き、中を層のサブフォルダ（`domain/`、`durable-object/`、`http/`）に分ける。置くもの: 種類の型、その種類だけにかかる受け付けの決まり、置き場の型と実装、受け口のスキーマと変換、その種類の同期のテスト。今は `src/weight-record/`、`src/account-settings/`、`src/meal/`、`src/meal-estimation-status/`、`src/dish/`、`src/dish-estimation-status/`、`src/ingredient/`、`src/notice/`、`src/usual-weighing-time/`、`src/weight-trend/`、`src/sent-text/`、`src/sent-text-status/`、`src/ai-utterance/`、`src/goal/`、`src/daily-guide/`、`src/expenditure-estimate/`、`src/weekly-review/`、`src/subscription-status/`。記録の種類ではない推定の出来事と推定の流れは `src/estimation/`、返事の流れと、読み分けと返事の提供元は `src/reply/`、Durable Object の入口ごとの処理（アカウントの口）は `src/account/domain/` に置く。経路、認証、観測、`AccountDurableObject`、Durable Object の移行の並び、種類をまたぐ同期の仕組み（書き込みの当て方、同期の置き場の型と実装）は、今の層の置き場に残す
- 層は oxlint の `no-restricted-imports`（`.oxlintrc.json` の `overrides`）で守る。`src/domain/` と `src/<種類>/domain/` からは、受け口（`http`）、Durable Object（`durable-object`）、`cloudflare:*`、`hono` を import できない。import の文字列だけを見るので、別名の import を使い始めたら dependency-cruiser を考える
- 機能を第一の軸にする切り方（`src/<機能>/` の下に層を置く）を採らなかった理由は、[コードの置き方を縦に切るか（#153）](https://github.com/gn-t-k/nu-tori/issues/153) にある
- Durable Object のクラスは `instrumentDurableObjectWithSentry` で包み、Worker と同じ Sentry の設定（`src/observability/create-sentry-options.ts`）を渡す。包まないと、アラームの例外が Sentry に届かない
- ドメイン層は、実行基盤の型や API に触れない。ドメイン層が要る置き場と外への呼び出し（記録の置き場、写真の控え、LLM の提供元など）は、ドメイン層が型を定め、基盤に固有の層（Durable Object、D1・R2・LLM の提供元・Apple の API への入出力）がそれを実装する
- 1人の記録を読み書きするドメインの処理は、その人の Durable Object の中で動かす。入口（受け口の Worker からの要求と、アラーム）ごとの処理は、アカウントの口（`src/account/domain/account-requests.ts` の `accountRequests`）に関数を1つずつ置く。関数は、ドメイン層が型を定めたストア（`AccountStores` のうち要るもの）と要求と今の時刻（要るときだけ）を受け、結果と、起きた利用状況の出来事（`AccountResponse`）を返す。アラームの時刻は返さない（下の「Durable Object のクラス」）。見直しを起こす要求は、要求ごとのログに足す値（`LoggedAccountResponse` の `requestLog`）も返す。出来事を作るところ（口、流れ、種類）は利用状況の設定を読まない
- Durable Object のクラスは、`setUser` でアカウント ID を付ける、ストアを組んで口を呼ぶ、アラームを張り直す、返った出来事を送る、だけをする薄い層にする。受け口からの要求のあとは、記録を変えたかによらず、`respondRearmingAlarm` がいつも仕事の並びから次の時刻を出し直して張る（無ければ外す）。要求ごとに張るかを選ばない（選ぶと、時刻を動かす記録を書いた要求で張り忘れる。#778）。例外は、表ごと消す記録の削除（Durable Object が渡す `eraseRecords` が表と一緒にアラームも外す）と、アラーム自身（口が出した時刻に張る）。送るかどうか（利用状況の設定）は、どの入口の出来事も通る送る前の1か所（`armAlarmAndSendUsageEvents` が呼ぶ `selectSendableUsageEvents`）で、口が答えを出し終えた直後の設定で決める。出来事を送る道をほかに作らない。`alarm()` も同じ形にし、ログと Sentry への報告だけを足す。入口を足すときは、口に関数を足してから、Durable Object に同じ形のメソッドを足す
- HTTP の受け口は、記録を読み書きする要求なら、セッションを確かめ、回数の歯止めをかけてから、その人の Durable Object を呼ぶだけにする。まだセッションのないサインインと Apple のサーバー間通知は、受け口の Worker の認証で受ける。アカウントの削除は、受け口の Worker でドメイン層を呼ぶ。Durable Object の中身を消すときも、その Durable Object の入口を呼んで行う
- 受け口は、Durable Object を呼ぶたびにアカウント ID を渡す。Durable Object の中では、その呼び出しの Sentry の報告に user の ID として付ける
- 受け口のスキーマは要求の形だけを確かめる。受け付ける値の範囲はドメイン層で確かめる
- 想定した失敗（`docs/agents/languages/typescript.md` の「失敗の扱い」）を状態コードに直すのは受け口で行う
- 失敗した段（R2、LLM の提供元の呼び出しなど）は、例外の `stage` の欄に持たせる。受け口の要求ごとのログ（`src/http/observe-request.ts`）が、例外の名前と一緒に出す
- 開発用と本番で出たログと、呼び出しの数・誤り・CPU 時間を読むときは、`docs/agents/tooling.md` の「Cloudflare を読む」を読む
- Durable Object の RPC を越えたエラーには、`name`・独自のフィールド・`cause` が届き、`instanceof` は効かない（互換フラグ `enhanced_error_serialization`。`compatibility_date` が 2026-04-21 以降なら既定で有効）。`legacy_error_serialization` は足さない。足すと `name` が `"Error"` になり、独自のフィールドも消える

**Why:** ドメイン層を基盤から切り離しておくと、基盤を移るとき（出口は ADR-0012）に書き直すのが基盤に固有の層だけで済む。

## API

- REST＋OpenAPI。経路をスキーマつきで書き、書き出した OpenAPI の文書を `openapi.json` に置く。型の正本は経路のスキーマで、経路を変えたら `scripts/check server --fix` で書き出し直し（`scripts/check server` が最新かを確かめる）、`scripts/check ios --fix` でアプリのクライアントも生成し直す（`ios/AGENTS.md` の「API」）
- 経路には `operationId` を付ける。アプリで生成するクライアントのメソッドの名前になる
- 出回っている最も古い版のアプリとも動くようにする。API の変更は足すだけにし、壊す変更は新しい版のエンドポイントとして出す。最低バージョン（本番の `vars` の `MINIMUM_APP_BUILD`）より古いビルドは締め出すので、この「最も古い版」から外れる。締め出すかの線引きと上げる手順は `docs/agents/ios-release.md`
- 締め出しは受け口の入口（`src/http/reject-unsupported-app-build/`）で扱う。アプリが付けるビルド番号のヘッダー `X-App-Build` と、締め出したときの 426（本文は `{ "code": "app_build_unsupported" }`）は、経路のスキーマと OpenAPI の文書に載せない。`/v1` の経路は Apple のサーバー間通知（Sign in with Apple の通知と App Store のサーバー通知）を除いてすべて判定にかかるので、アプリから来ない経路を足すときは入口の外す経路に名前を足す

## 同期の帳簿

- 記録の種類を足す・直すとき、同期の帳簿（`src/domain/sync-ledger/`）に触るとき、端末の書き込みの外（受け口の要求、アラーム）で記録を変えるとき、書き込みで PostHog に送る出来事を足すときは、`docs/agents/server-sync-ledger.md` を読む

## 出し方のページの例

- 出し方のページ（`site/src/pages/daily-guide-page.tsx`）の「Aさんの例」の数字（`site/src/pages/daily-guide/daily-guide-example.json`）は、`scripts/print-daily-guide-example.ts` がドメイン層の関数で出す。推定消費カロリー・1日の目安・毎週の見直しの決まりを変えたら、`scripts/check server --fix` で書き出し直し、ページの本文が新しい数字と合うかを読む（筋が変わると、ページの書き出しが止まる）

## 認証

- 認証は Better Auth に任せる（ADR-0019）。Better Auth の表は D1 の中の認証の置き場に閉じ、ほかの表と Durable Object はアカウント ID だけを見る
- Better Auth の HTTP の口（`/api/auth/*`）は出さない。受け口の経路から Better Auth の `api` と `$context` を呼ぶ。経路をスキーマつきで OpenAPI の文書に載せ、Apple の識別子を返す口（アカウントの一覧など）を出さないため

## 身体データ

- 身体データと使い始める前の摂取エネルギーは、目標と推定消費カロリーの計算に使ったら捨て、DB にもログにも残さない（ADR-0009）

## 目標の設定と週の見直し

- 目標の設定の要求（`/v1/goal-setup/*`）と、週の見直し・達成・期限の日の確定に触るときは、`docs/agents/server-goals.md` を読む

## DB

- スキーマは素の SQLite で書く。表は Drizzle ORM で宣言して読み書きし、移行は手書きの SQL で持つ（ADR-0021）。Drizzle Kit は使わない
- Drizzle の宣言は、今の表の形に合わせて手で書く。記録の種類の表は `src/<種類>/durable-object/` に、帳簿の表と種類をまたぐ表は `src/durable-object/` に置き、全部を `durable-object-tables.ts` に集める。宣言は1ファイル1つの表の束を export する。移行を足すときは、SQL と宣言の両方を書く
- 表を足す・置き場を探すときの、仕様ごとの表の置き場は `docs/agents/table-design.md` の「既存の表の置き場」にある
- サブスクリプションの状態の種類は、Durable Object の外の事実（D1 のテストユーザーの旗と、環境変数 `BILLING_STARTED_ON` の課金を入れた日）も読む。Durable Object は、記録の置き場を組む要求とアラームのたびに `src/subscription/d1/read-subscription-account.ts` で読み、`createRecordKindStores` に渡す（旗の変化を Durable Object が知らないため）。旗の変化と時刻の区切りは、アラームで動かす課金の仕事が、区切りの時刻（`src/subscription-status/domain/find-subscription-check/`）に状態の記録の変更を足して届ける。保留した推定のあるアカウントがテストユーザーなら、切れていたあいだに旗を立てたので、すぐ動いて一度足し、保留を再開する（`read-subscription-check.ts`）。帳簿にまだ状態の変更が無い（課金を入れる前からの）アカウントには、すぐ動いて一度足す
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
  - アラームで動かす仕事（課金、読み分け、推定、返事、写真の控えの消し残しの消し直し）は、「進める」と「次に動く時刻」を対にした値（`src/domain/alarm-job.ts`）にして、1つの並び（`src/domain/account-alarm-jobs.ts`）に置く。アラームで動かすものを足すときは、この並びに足す。アラームは並びの順に進め、エラーは並びで先の仕事のものを報告する
  - アラーム1回分（仕事を順に進め、次に張る時刻と報告するエラーを決める）は `src/domain/run-account-alarm.ts` が、要求のあとに張るいちばん早い時刻は `src/domain/compute-next-alarm-at.ts` が、どちらもこの並びから出す。前者はアカウントの口が、後者は Durable Object の `respondRearmingAlarm` が呼ぶ。Durable Object の `alarm()` は、口から返った時刻に張り、Sentry・PostHog・ログに出し、エラーを投げるだけにする
  - 写真の控えの消し直しに失敗したアラームは、消し残しの時刻（今）を除いたいちばん早い時刻に張り直す（今に張り直さず、Cloudflare のアラームのやり直しに任せる）。仕事が `left_to_alarm_retry` を返すと、その仕事の時刻を除く
  - アラームの中のアカウント ID は `ctx.id.name`（`idFromName` で付けた名前）から得る。テストの実行環境でも、張ったアラームはひとりでに動くので、アラームの結果を確かめるテストは `runDurableObjectAlarm` で動かしたうえで `vi.waitFor` で待つ
- 記録に対しては、全員をまたぐ SQL は書けない。全員をまたぐ分析は、記録を書くときに分析用の出来事を PostHog に送って行う

## テスト

- テストは Workers の実行環境の中で回す
- D1 と Durable Object の中身は、テストのあいだ消えない。テストごとに新しい ID（`generateRecordId()`）で書く
- LLM の評価（`evals/`）は手で回し、CI と `scripts/check` には入れない。回し方（揺れを見る回数、別の版との比べ）は入口の `evals/run-eval.ts`・`evals/compare-eval.ts` にある。PR の本文には、出た要約を、評価したコミットの SHA ごと貼る
- 開発用の環境で主な流れを確かめるジョブ（`e2e/`）と、そのためのサインインの口（`/v1/e2e/*`）に触るときは、`docs/agents/server-e2e.md` を読む

## デプロイ

- main へのマージごとに、開発用、本番の順にデプロイする。どちらも D1 の移行を当ててから Worker を出す。TestFlight の版は main から配られて本番につなぐので、main にある API は本番にも出ているようにする
- 本番の前に、浅い確認（開発用に出した Worker が応答し、D1 を読めるかだけを見る）を挟む。`deploy.yml` の `shallow-check` が開発用の `GET /health`（`src/http/health-routes/`）を呼び、本番のデプロイは、開発用のデプロイと浅い確認の両方が通ったときだけ動く。主な流れを通す `verify-development` は本番を待たせない
- `GET /health` は認証なしで呼べるので、本文に記録の中身もアカウントの情報も入れない（ADR-0017）。アプリの API の版（`/v1`）の外に置き、OpenAPI の文書に載せず、強制アップデートの判定にもかけない
- 出したあとに壊れたら、前の版のコードに戻さず、直した新しい版を出す（roll forward）。移行は足すだけでも、既存の列に新しい値（記録の種類 `meal` など）が入るので、前の版のコードがそれを読めず、そのアカウントの取りに行く要求が失敗し続けうる
  - 例外は、依存だけを上げた PR の revert。依存だけの PR は DB に書く値を変えないので、前の版のコードに戻しても読めない値が無い。戻し方は `docs/agents/dependencies.md` の「壊れたときの戻し方」
- CI の API トークンの権限は、Workers の Admin（まだ無い Worker を作るのに要る）、D1 の編集、`nu-tori.app` のゾーンの Workers Routes の編集（独自ドメインを付け替えるのに要る）だけ。レガシーの Workers Scripts は使わない。CI にほかの製品を触らせるときは、開発者にトークンの権限を足してもらう
