---
name: verify-server
description: "nu-tori のサーバー（server/）を手元で wrangler dev で立て、端末と同じ API を叩いて、触れた機能が動くことを証拠つきで確かめる。PR を出す前と PR に push する前の確かめ（docs/agents/git.md の「動かして確かめる」）で使う。"
---

# サーバーを動かして確かめる

サーバーを空の状態から手元に立て、端末と同じ形の要求を送り、応答と、取りに行く要求に届いた記録で、機能が動いたことを示す。テストが通ることとは別に、本物の経路（受け口 → Durable Object → D1・R2）を通ったかを見る。

道具はこのフォルダの `scripts/` にある。回のフォルダを取る道具は、引数なしで呼ぶと使い方を言って止まる。下では `S=.agents/skills/verify-server/scripts` とする（リポジトリの直下から呼ぶ）。

## 起動

```bash
run=$($S/start.sh)        # ポートを変えるときは $S/start.sh 8800
```

- 空の DB に D1 の移行を当て、`wrangler dev --local` を開発用の設定（`wrangler.jsonc` の上の階層）で立てる。Durable Object の移行は、最初の要求で各 Durable Object が当てる
- 立ったと言えるのは、ログの `Ready on` と `GET /health` が `{"status":"ok"}` の両方が揃ったとき。最後の行に回のフォルダ（`.scratch/verify-server/<時刻>-<ポート>/`、gitignore 済み）を出す
- 秘密の値は手元だけの偽物で、Apple と Sentry には届かない。確かめのサインインの口（`/v1/e2e/*`、`docs/agents/server-e2e.md`）は、この回だけの秘密の値で開く
- 推定・読み分け・返事は Anthropic を呼ぶ。開発用のワークスペース（`nu-tori-development`）の鍵を `VERIFY_SERVER_ANTHROPIC_API_KEY` で渡して立てたときだけ、結果まで進む。渡さなければ呼び出しは `authentication_error` で失敗し、そこから先は下の「確かめられないとき」の入口になる
- 1つの回は1つのポートと1つのフォルダを持つので、並べて立ててよい。自分で立てていないポートで何かが応答していれば、`start.sh` は断って止まる。人の開いている `wrangler dev` を叩かない

## Doctor

おかしいと思ったら、まずこれを回す。読むだけで、何も変えない。

```bash
$S/doctor.sh "$run"
```

この回の `wrangler dev` が動いているか、`/health` が答えるか、立てたときと今で `server/` の中身（作業中の変更と、追跡していない新しいファイルを含む）が同じかを見る。`NG` があれば `stop.sh` で止め、`start.sh` で立て直す。`server/` を変えたら立て直す（`wrangler dev` は変更を読み直すが、どの版を確かめたかを証拠に残すため）。確かめたコミットは `"$run/run.env"` の `COMMIT`。

## 動かし方

アプリの代わりに、端末と同じ形の要求を `device.sh` で送る（下では `D=$S/device.sh`）。中身は `server/e2e/cli/drive-device.ts` で、主な流れ（`server/e2e/run-main-flow.ts`）と同じ `server/e2e/device-client.ts` を使う。

```bash
$D sign-in "$run" <名前>                         # 新しいアカウント。セッションは名前を付けて回のフォルダに残る
$D push "$run" <名前> '<書き込みの JSON の配列>'   # POST /v1/sync/writes
$D pull "$run" <名前>                            # GET /v1/sync/changes を最後まで。変更の配列を出す
$D call "$run" <名前> <メソッド> <パス>            # ほかの API を1回呼ぶ
$D scenario "$run" <名前> <場面>                  # 時の経過で起きる知らせの場面のアカウント（docs/agents/ios-mac.md の「時の経過で起きる知らせを確かめる」）
$D                                              # オプション（時刻の差し替え、本文、--timeout など）の使い方
```

送った要求と応答は `"$run/evidence/requests.log"` に足される。

主な流れ（サインイン → 体重 → 目標と週の見直し → 写真と文章の食事の推定 → 返事 → 削除 → 無料体験の終わったアカウント）を1回で通すときは、merge のあとに CI が開発用の環境に向けるのと同じ入口を、この回に向ける。

```bash
. "$run/run.env"
(cd server && E2E_BASE_URL="$BASE_URL" E2E_SIGN_IN_SECRET="$E2E_SIGN_IN_SECRET" E2E_ESTIMATION_TIMEOUT_SECONDS=30 pnpm exec tsx e2e/cli/run-main-flow.ts)
```

通った段を1行ずつ出し、落ちたら段と理由を出して 1 で終わる。Anthropic の鍵が無い回では、週の見直しのあと、写真の食事の推定を待つ上限（上では 30 秒）で落ちる。そこまでの段が通ったことは証拠になるが、地図の入口を1つずつ通す代わりにはならない（主な流れは、入口ごとの別の道を通さない）

## 地図

`features/README.md` が索引で、機能ごとのファイルが確かめる手順。

## 証拠

- 証拠は `"$run/evidence/"` に残る。`requests.log` に、送った要求と、返った状態コードと本文が並ぶ
- 動いたと言えるのは、ユーザーの経路（端末が呼ぶ API）で操作し、その結果を別の見方（取りに行く要求に届いた記録、続く要求の状態コード）で読めたとき。書き込みが `applied` を返しただけでは足りない
- 確かめの口（`/v1/e2e/*`）は、本物の経路で見えないもの（推定の失敗の理由）を読むときと、Apple を通せないサインインの代わりにだけ使う
- PR の本文の「確かめ」（`docs/agents/git.md` の「動かして確かめる」）に書く見えた結果は、状態コードと、届いた記録の種類と値

## 確かめられないとき

次の入口は手元で通せない。`docs/agents/git.md` の「動かして確かめる」で「確かめていない」と書くときに、確かめる場所をここから引く。ほかの入口を通せなかったときは、試したコマンドと、揃わなかった前提を書く。

- Anthropic の鍵が無い回では、推定・読み分け・返事の結果まで進まない。推定が始まる（`estimating`）ことと、Anthropic まで届いた（確かめの口で `authentication_error`）ことまでが確かめられる。結果は、merge のあとに `deploy.yml` の `main-flow-on-development`（開発用の環境で本物の提供元を通す）が確かめる
- Sign in with Apple、Apple のサーバー間通知、App Store の取引は、Apple を通すので手元で動かせない。TestFlight の版で確かめる
- アプリの画面は、このスキルの外。Mac のセッションの UI テストで確かめる。時の経過で起きる知らせは、この回に作った場面のアカウントでデバッグビルドを開いて見られる（`docs/agents/ios-mac.md` の「時の経過で起きる知らせを確かめる」）

## 片付け

```bash
$S/stop.sh "$run"
```

この回が立てたプロセスの組だけを止め、DB と偽の秘密の値とセッションを消す。`evidence/` と `wrangler.log` は残す。止めるのはいつも `stop.sh "$run"` で、失敗して立て直すときも、そのたびに回す。
