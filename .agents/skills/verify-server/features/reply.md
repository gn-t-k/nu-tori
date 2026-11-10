# 送った文章と返事

ユーザーが入力欄に書いて送った文章は、読み分けで食事か会話になる。会話なら返事が作られ、送った端末は見守る要求で本文が流れてくるのを読み、ほかの端末は取りに行く要求で返事を受け取る。返事を作れなかった文章は送り直せ、食事と読み分けられた文章は会話として送り直せる。

## Sub-features

- `reply-send` 送った文章が届き、送った文章の状態ができる
- `reply-classify` 読み分けで、食事か会話になる（食事なら [食事の記録と推定](./meal-estimation.md) の文章の食事）
- `reply-stream` 見守る要求で、返事の本文が流れ、返事ありで閉じる
- `reply-pull` 取りに行く要求で、返事が届く
- `reply-resend` 返事を作れなかった文章を送り直す
- `reply-resend-as-conversation` 食事と読み分けられた文章を、会話として送り直す

## How to get to it (user POV)

- 入力欄に書いて送る。端末は `create_sent_text` を送り、続けて `GET /v1/sent-texts/{sentTextId}/reply-stream` をつなぐ
- ほかの端末で開く。`GET /v1/sync/changes` で `sent_text_status` と返事を取りに行く
- 返事を作れなかった文章の「送り直す」。端末は `resend_sent_text` を送る
- 食事になった文章の「会話として送り直す」。端末は `resend_sent_text_as_conversation` を送る

## Driving it with verify-server

Preconditions:

- `$D sign-in "$run" reply` で作ったアカウント
- 返事まで見るなら、`VERIFY_SERVER_ANTHROPIC_API_KEY` に開発用のワークスペースの鍵を渡して立てた回

- **送る。** `t=$($D uuid)` として、`$D push "$run" reply "[{\"type\":\"create_sent_text\",\"sentText\":{\"id\":\"$t\",\"body\":\"今日はよく歩いたので、少し脚が疲れた\",\"sentAt\":$(date +%s)000,\"timeZone\":\"Asia/Tokyo\"}}]"` を送る。`applied`
- **見守る。** `$D call "$run" reply GET /v1/sent-texts/$t/reply-stream --timeout 120` を、送ったらすぐに送る（返事ができ終わってからつなぐと、本文が流れずに閉じる）。Server-Sent Events で `reply_started`、`text_delta` が流れ、最後が `replied` で閉じる。食事と読み分けられた文章は `classified_as_meal`、止まれば `reply_halted`、作れなければ `reply_failed` で閉じる
- **読み分け。** 数秒おきに `$D pull "$run" reply | jq -c --arg t "$t" '[.[] | select(.kind=="sent_text_status" and .record.sentTextId==$t) | .record] | last'` を読む。`classification` が `conversation` になり、`replyStatus` が進む
- **取りに行く。** 取りに行く応答に、`$t` に応える返事（種類 `ai_utterance`）が届き、本文が見守る要求で流れた分と同じ。`sent_text_status` の `replyStatus` が返事ありに進む
- **食事の文章。** 本文を `server/e2e/meal-text-body.ts` の文面にして送る。`classification` が `meal` になり、`sentTextId` が `$t` の `meal` ができる
- **会話として送り直す。** 食事になった文章に `$D push "$run" reply "[{\"type\":\"resend_sent_text_as_conversation\",\"sentTextId\":\"$t\"}]"` を送る。`applied` で、その文章の食事が消え、返事が作られる
- **送り直す。** `replyStatus` が `failed` か `halted`（`daily_limit` を含む）の文章に `$D push "$run" reply "[{\"type\":\"resend_sent_text\",\"sentTextId\":\"$t\"}]"` を送る。`applied` で、`replyStatus` が `awaiting` に戻り、返事が作られる
- **止まった文章を送り直す。** `$D sign-in "$run" rexp --as-of "$(date -u -d '-60 days' +%FT%TZ)"` のアカウント（無料体験の終わったアカウント）で、セッションの名前を `rexp` にして「送る」と「見守る」を回す。見守る要求が `reply_halted`（`subscription_expired`）で閉じる。`$D pull "$run" rexp | jq -c --arg t "$t" '[.[] | select(.kind=="sent_text_status" and .record.sentTextId==$t) | {sequence, replyStatus: .record.replyStatus}] | last'` で `sequence` を控えてから、上の「送り直す」を送る。`applied` で、同じ読み方の `sequence` が控えより進み、`replyStatus` はまた `halted`（いったん `awaiting` に戻り、また止まった）。鍵が無い回でも同じ

## Gotchas

- 読み分けの呼び出しが失敗すると、文章は会話になる。鍵の無い回でも `classification` が `conversation` になるので、それを読み分けが動いた証拠にしない。鍵の無い回で確かめられるのは、送った文章が届き、送った文章の状態ができるまでと、「止まった文章を送り直す」
- 鍵の無い回の見守る要求は、返事ができないので閉じない。`--timeout` を付けて送る。切れると 1 で終わり、それまでに届いた分を出して `requests.log` に残す
- 送り直す書き込みは、送り直しても何も変わらない文章（すでに返事を待っている・返事のある文章、すでに会話の文章）にも `applied` を返す。`applied` でなく、`replyStatus` と返事が届くかを見る
- 「送り直す」で返事が作られるところは、手元では確かめられない（確かめる場所は SKILL.md の「確かめられないとき」）。鍵の無い回は返事の呼び出しの再試行が続いて `failed` に着くまで待てず、鍵のある回は返事が作れてしまい `failed` に着かない。「止まった文章を送り直す」は、無料体験が終わったままなのでまた止まる
- 「会話として送り直す」は、鍵の無い回では読み分けが食事にならないので確かめられない
