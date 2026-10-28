# 確かめのジョブのためのサインインの口

パスは `server/` から数える。

- 開発用の環境で主な流れを確かめるジョブ（`docs/agents/tooling.md` の「CI」）は、Apple を通せないので、`POST /v1/e2e/sessions`（`src/http/e2e-session-routes/`）でサインインする。毎回新しいアカウントを作り、`sessionToken` と `accountId` を返す。OpenAPI の文書には載せない（アプリのクライアントに入れない）
- 本番で開くと誰でも入れてしまうので、次のすべてが揃ったときだけ開き、ほかは口が無いのと同じ 404 にする
  1. `SENTRY_ENVIRONMENT` が `development`（許可する名前を挙げる。本番や綴りの違う名前は閉じる）
  2. 秘密の値 `E2E_SIGN_IN_SECRET` が置かれていて、32 文字以上
  3. `x-e2e-sign-in-secret` ヘッダーがその秘密の値と一致する（一致しなければ 401。ハッシュにして定数時間で比べる）
- 新しいアカウントは前の週を持たないので、ジョブは目標の設定の要求（`/v1/goal-setup/*`）を過去の時刻に送ったことにし、開始の日を前の週に置いて、次の取りに行く要求で週の見直しが届くことを確かめる。`x-e2e-requested-at`（ISO 8601）と `x-e2e-sign-in-secret` を送り、上の 1〜3 が揃ったときだけその時刻で計算する。揃わないか時刻が読めなければ、ヘッダーが無いのと同じに今の時刻にする（断らず、差し替えがあることを漏らさない。`src/http/e2e-access/resolve-requested-at.ts`）
- 課金の判定を確かめるため、ジョブは2つ目のアカウントを、サインインの口に `x-e2e-requested-at` を付けて60日前に使い始めたことにして作り、写真の食事の推定の状態が `awaiting_subscription` になることを確かめる。無料体験の最後の日は使い始めた日と課金を入れた日の遅いほうから数えるので、開発用の `BILLING_STARTED_ON` は30日より前の日にしておく（ジョブは、無料体験が終わっていなければそう書いて落ちる）。時刻の差し替えの条件は目標の設定の要求と同じ
- ジョブは、推定が `failed` で終わった理由を `GET /v1/e2e/meals/{mealId}/last-estimation-attempt`（`src/http/e2e-estimation-attempt-routes/`）で読む
- `E2E_SIGN_IN_SECRET` は開発用の Worker にだけ置き、本番の `wrangler.jsonc` と本番の Worker に書かない。置かなくても動き、口が閉じるだけなので、`secrets.required` には書かない（書くと、置くまで開発用のデプロイが失敗し、本番のデプロイも止まる）。型は `src/e2e-sign-in-secret.d.ts` で足す。本番の設定に名前を書いていないことは、`e2e-session-routes.test.ts` が `wrangler.jsonc` の文字列で確かめる
- 確かめる流れは `e2e/run-main-flow.ts`（Workers の実行環境のテストで、偽の提供元を差して通る）、実行の入口は `e2e/verify-development.ts`（Node で `pnpm exec tsx` で動かす）、送る写真と出典は `e2e/photos/`
