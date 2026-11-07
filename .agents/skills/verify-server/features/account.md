# サインインとアカウントの削除

ユーザーはサインインして使い始め、無料体験中のアカウントになる。アカウントを削除すると、記録がすべて消え、そのセッションでは何も読めなくなる。

## Sub-features

- `account-sign-in` 新しいアカウントを作り、セッションを始める
- `account-free-trial` 作ったばかりのアカウントが無料体験中になる
- `account-expired-trial` 無料体験の終わったアカウントになる（30日より前に使い始めた）
- `account-delete` アカウントと記録をすべて消し、セッションを使えなくする

## How to get to it (user POV)

- アプリの最初の画面で Sign in with Apple を選ぶ。端末は `POST /v1/sessions` を呼ぶ（手元では Apple を通せないので、確かめのサインインの口 `POST /v1/e2e/sessions` で代える）
- アプリの設定でアカウントを削除する。端末は `DELETE /v1/account` を呼ぶ
- Apple ID の設定で nu-tori の Sign in with Apple をやめる。Apple のサーバー間通知が届く（手元では動かせない）

## Driving it with verify-server

Preconditions:

- 立てたばかりの回（アカウントはこの手順で作る）

- **サインイン。** `$D sign-in "$run" main` を送る。アカウント ID が1行出て、`requests.log` に `POST /v1/e2e/sessions -> 201` が残る
- **無料体験中。** `$D pull "$run" main | jq -c '.[] | select(.kind=="subscription_status") | .record'` を読む。`freeTrial.type` が `available` で、`lastDay` が今日より後
- **無料体験の終わったアカウント。** `$D sign-in "$run" expired --as-of "$(date -u -d '-60 days' +%FT%TZ)"` で作り、同じく `subscription_status` を読む。`freeTrial.lastDay` が今日より前
- **削除。** `$D call "$run" main DELETE /v1/account` を送る。状態コード `204`
- **削除のあと。** `$D call "$run" main GET /v1/terms-agreement` を送る。状態コード `401`（セッションが消えた）

## Gotchas

- `POST /v1/sessions`（Sign in with Apple）と、Apple のサーバー間通知（`/v1/apple-server-notifications` など）は手元で通せない。サインインの入口を変えた PR は「確かめていない」と書き、TestFlight の版で確かめる
- 無料体験の最後の日は、使い始めた日と課金を入れた日（開発用の `BILLING_STARTED_ON`、`wrangler.jsonc`）の遅いほうから数える。課金を入れた日が30日より前でないと、60日前に使い始めても無料体験が終わらない
- 削除の `204` だけでは足りない。続く要求の `401` まで見る
