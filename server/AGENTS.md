# server

nu-tori のサーバー。TypeScript で書き、Cloudflare で動かす（ADR-0011・0012）。

## 構成

- 構成の正本は `wrangler.jsonc`。上の階層が開発用で、本番は `env.production`。つなぎ（Durable Object、D1、R2 など）は環境に受け継がれないので、足すときは両方に書く
- Worker の型の宣言（`worker-configuration.d.ts`）は `wrangler types` が `wrangler.jsonc` から書き出す。コミットせず、`scripts/check server` が毎回書き出す
- Workers で動かないライブラリが要る処理が出たら、その部分だけ別の基盤に置く
- 秘密の値は `wrangler secret` に置く。足したら、`wrangler.jsonc` の `secrets.required`（開発用と本番の両方）に名前を、`vitest.config.ts` にテストの値を書く。GitHub Actions の分は、ルートの `AGENTS.md` の「リポジトリ全体の決定」

## 層

- 置き場: HTTP の受け口は `src/http/`、Durable Object は `src/durable-object/`、ドメイン層は `src/domain/`、認証（Better Auth と、Apple の API への入出力）は `src/auth/`、観測（Sentry の設定と、PostHog の API への入出力）は `src/observability/`
- Durable Object のクラスは `instrumentDurableObjectWithSentry` で包み、Worker と同じ Sentry の設定（`src/observability/create-sentry-options.ts`）を渡す。包まないと、アラームの例外が Sentry に届かない
- ドメイン層は、実行基盤の型や API に触れない。ドメイン層が要る置き場と外への呼び出し（記録の置き場、写真の控え、LLM の提供元など）は、ドメイン層が型を定め、基盤に固有の層（Durable Object、D1・R2・LLM の提供元・Apple の API への入出力）がそれを実装する
- 1人の記録を読み書きするドメインの処理は、その人の Durable Object の中で動かす。Durable Object のクラスは、ドメイン層を呼ぶ入口（受け口の Worker から、アラームから）と、ドメイン層が定めた記録の置き場の実装と、ほかの基盤に固有の実装をドメイン層に渡すことだけを持つ薄い層にする
- HTTP の受け口は、記録を読み書きする要求なら、セッションを確かめ、回数の歯止めをかけてから、その人の Durable Object を呼ぶだけにする。まだセッションのないサインインと Apple のサーバー間通知は、受け口の Worker の認証で受ける。アカウントの削除は、受け口の Worker でドメイン層を呼ぶ。Durable Object の中身を消すときも、その Durable Object の入口を呼んで行う
- 受け口のスキーマは要求の形だけを確かめる。受け付ける値の範囲はドメイン層で確かめる

**Why:** ドメイン層を基盤から切り離しておくと、基盤を移るとき（出口は ADR-0012）に書き直すのが基盤に固有の層だけで済む。

## API

- REST＋OpenAPI。経路をスキーマつきで書き、書き出した OpenAPI の文書を `openapi.json` に置く。型の正本は経路のスキーマで、経路を変えたら `scripts/check server --fix` で書き出し直す（`scripts/check server` が最新かを確かめる）。文書を使う側は `ios/AGENTS.md` の「API」
- 出回っている最も古い版のアプリとも動くようにする。API の変更は足すだけにし、壊す変更は新しい版のエンドポイントとして出す

## 認証

- 認証は Better Auth に任せる（ADR-0019）。Better Auth の表は D1 の中の認証の置き場に閉じ、ほかの表と Durable Object はアカウント ID だけを見る
- Better Auth の HTTP の口（`/api/auth/*`）は出さない。受け口の経路から Better Auth の `api` と `$context` を呼ぶ。経路をスキーマつきで OpenAPI の文書に載せ、Apple の識別子を返す口（アカウントの一覧など）を出さないため
- Better Auth の版を上げるときは、変更履歴で中核の表の変更を確かめる（1.x の中でも入ったことがある）

## 身体データ

- 身体データと使い始める前の摂取エネルギーは、目標と推定消費量の計算に使ったら捨て、DB にもログにも残さない（ADR-0009）

## DB

- スキーマは素の SQLite で書く
- D1 のスキーマの変更は、`d1-migrations/` の移行の SQL ファイルで行う
- Durable Object の中のスキーマの変更は、`durable-object-migrations/` に版つきの SQL ファイルを置き、`src/durable-object/durable-object-migrations.ts` の並びに足す。各 Durable Object が起動するときに、まだ当てていない版を自分の DB に当てる
- どちらの移行も足すだけにし、1つ前の版のコードでも動く形にする（下の「デプロイ」で、移行を当ててからコードを出すため）
- Durable Object のアラームは一度に1つしか張れない。アラームで動かすもの（推定など）は、予定を DB に持ち、いちばん早い予定にアラームを合わせる
- 記録に対しては、全員をまたぐ SQL は書けない。全員をまたぐ分析は、記録を書くときに分析用の出来事を PostHog に送って行う

## テスト

- テストは Workers の実行環境の中で回す
- D1 と Durable Object の中身は、テストのあいだ消えない。テストごとに新しい ID（`crypto.randomUUID()`）で書く

## デプロイ

- main へのマージごとに、開発用、本番の順にデプロイする。どちらも D1 の移行を当ててから Worker を出す。TestFlight の版は main へのマージごとに配られて本番につなぐので、main にある API は本番にも出ているようにする
- デプロイは `.github/workflows/deploy.yml`（環境ごとの手順は `deploy-worker.yml`）
- CI の API トークンの権限は、Workers の Admin（まだ無い Worker を作るのに要る）、D1 の編集、`nu-tori.app` のゾーンの Workers Routes の編集（独自ドメインを付け替えるのに要る）だけ。レガシーの Workers Scripts は使わない。CI にほかの製品を触らせるときは、開発者にトークンの権限を足してもらう
- D1 と R2 は、`wrangler.jsonc` に書く前に、開発者に場所のヒント（`--location apac`）を付けて手で作ってもらう。デプロイのときの自動作成は場所のヒントを渡せず、CI が作ると CI の近くに置かれる。`wrangler.jsonc` には名前だけを書き、CI は名前で見つける

## 版を上げる

- npm の依存は Dependabot が上げる。Node（`.node-version`）と pnpm（`package.json` の `packageManager`）は、月に一度、開発者に頼まれたときと Dependabot の PR を片付けるときに、最新を確かめて手で上げる
- pnpm は、Dependabot が対応する版（2026-09-28 時点で v12 まで）にとどめる。対応が広がったら上げる
- `@cloudflare/vitest-pool-workers` が対応する Vitest の版にとどめる（2026-09-28 時点で 4.x）。Dependabot は `.github/dependabot.yml` の `ignore` で Vitest のメジャーの版上げを除いているので、対応が広がったら手で上げ、`ignore` を外す
- `wrangler.jsonc` の `compatibility_date` は、`@cloudflare/vitest-pool-workers` が使う workerd が対応する日付までにする（それより後だと、テストの実行環境が起動しない）
