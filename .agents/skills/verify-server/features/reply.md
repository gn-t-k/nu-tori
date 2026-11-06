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

- `doctor.sh "$run"` が全部 `ok`
- `$S/sign-in.sh "$run" reply` で作ったアカウント
- 返事まで見るなら、`VERIFY_SERVER_ANTHROPIC_API_KEY` に開発用のワークスペースの鍵を渡して立てた回

- **送る。** `t=$($S/uuid.sh)` として、`$S/push.sh "$run" reply "[{\"type\":\"create_sent_text\",\"sentText\":{\"id\":\"$t\",\"body\":\"今日はよく歩いたので、少し脚が疲れた\",\"sentAt\":$(date +%s)000,\"timeZone\":\"Asia/Tokyo\"}}]"` を送る。`applied`
- **読み分け。** 数秒おきに `$S/pull.sh "$run" reply | jq -c --arg t "$t" '[.[] | select(.kind=="sent_text_status" and .record.sentTextId==$t) | .record] | last'` を読む。`classification` が `conversation` になり、`replyStatus` が進む
- **見守る。** `$S/api.sh "$run" reply GET /v1/sent-texts/$t/reply-stream --max-time 120` を送る。Server-Sent Events で `reply_started`、`text_delta` が流れ、最後が `replied` で閉じる
- **取りに行く。** 取りに行く応答に、`$t` に応える返事（種類 `ai_utterance`）が届き、本文が見守る要求で流れた分と同じ。`sent_text_status` の `replyStatus` が返事ありに進む
- **食事の文章。** 本文を `server/e2e/meal-text-body.ts` の文面にして送る。`classification` が `meal` になり、`sentTextId` が `$t` の `meal` ができる
- **会話として送り直す。** 食事になった文章に `$S/push.sh "$run" reply "[{\"type\":\"resend_sent_text_as_conversation\",\"sentTextId\":\"$t\"}]"` を送る。`applied` で、その文章の食事が消え、返事が作られる
- **送り直す。** `replyStatus` が `failed` の文章に `$S/push.sh "$run" reply "[{\"type\":\"resend_sent_text\",\"sentTextId\":\"$t\"}]"` を送る。`applied` で、`replyStatus` が `awaiting` に戻り、返事が作られる

## Gotchas

- 読み分けの呼び出しが失敗すると、文章は会話になる。鍵の無い回でも `classification` が `conversation` になるので、それを読み分けが動いた証拠にしない。鍵の無い回で確かめられるのは、送った文章が届き、送った文章の状態ができるまで
- 鍵の無い回の見守る要求は、返事ができないので閉じない。`--max-time` を付けて送る
- 見守る要求をつなぐ前に返事ができ終わると、本文が流れずに閉じる。送ってすぐにつなぐ
- 送り直す書き込みは、送り直せない状態の文章にも `applied` を返す。`applied` を証拠にせず、`replyStatus` と返事が届くかを見る。鍵の無い回では返事の呼び出しの再試行が続き、`failed` に着くまで待てないので、送り直す2つの入口は確かめられない
