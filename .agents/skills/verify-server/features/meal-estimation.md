# 食事の記録と推定

ユーザーが食事を撮る、撮っておいた写真を選ぶ、文章で書いて送ると、サーバーで推定が進み、料理と材料が届く。推定の状態は、写真を待っている、推定中を経て、推定できた・推定できなかったなどになる。無料体験の終わったアカウントでは、推定を始めずサブスクリプションを待っているになる。推定でできた料理の名前を直せ、食事を消せる。

## Sub-features

- `meal-captured` 撮った写真の食事を送ると、写真を待っている → 推定中 → 推定できた、と進む
- `meal-picked` 撮っておいた写真の食事も同じく進む
- `meal-written` 文章の食事（食事と読み分けた送った文章）が推定まで進む
- `meal-awaiting-subscription` 無料体験の終わったアカウントの食事が、サブスクリプションを待っているになる
- `meal-photo-backup` 写真の控えを送り、ほかの端末から取りに行ける
- `meal-rename-dish` 推定でできた料理の名前を直す
- `meal-delete` 食事を消す

## How to get to it (user POV)

- アプリで食事を撮る。端末は `create_meal`（`entryMethod` `captured`）を送り、続けて `PUT /v1/meal-photos/{photoId}` で写真の控えを送る
- 入力欄の「写真」から撮っておいた写真を選ぶ。`entryMethod` が `picked` の `create_meal` と写真の控え
- 入力欄に食事を書いて送る。端末は `create_sent_text` を送り、読み分けで食事になると文章の食事ができる（送った文章は [送った文章と返事](./reply.md)）
- 写真を持たない端末で食事を見る。端末は `GET /v1/meal-photos/{photoId}` を呼ぶ
- 料理の名前を直す（`update_dish`）、食事を消す（`delete_meal`）

## Driving it with verify-server

Preconditions:

- `doctor.sh "$run"` が全部 `ok`
- `$D sign-in "$run" meal` で作ったアカウント
- 推定できた、まで見るなら、`VERIFY_SERVER_ANTHROPIC_API_KEY` に開発用のワークスペースの鍵を渡して立てた回

- **撮った食事を送る。** `m=$($D uuid); p=$($D uuid); now=$(date +%s)000` として、`$D push "$run" meal "[{\"type\":\"create_meal\",\"meal\":{\"id\":\"$m\",\"eatenAt\":$((now-60000)),\"eatenAtUtcOffsetSeconds\":32400,\"sentAt\":$now,\"sentTimeZone\":\"Asia/Tokyo\",\"entryMethod\":\"captured\",\"photos\":[{\"id\":\"$p\"}]}}]"` を送る。`applied` で、取りに行くと `$m` の `meal_estimation_status` が `awaiting_photos`
- **写真の控えを送る。** `$D call "$run" meal PUT /v1/meal-photos/$p --body-file server/e2e/photos/oyakodon.jpg --content-type image/jpeg` を送る。状態コード `204`
- **写真の控えを取りに行く。** `$D call "$run" meal GET /v1/meal-photos/$p --out "$run/evidence/photo.jpg"` を送る。状態コード `200` で、`file "$run/evidence/photo.jpg"` が JPEG（端末が送った縮小版のまま）
- **推定が進む。** 写真の控えが届くと `estimating` になる。5 秒おきに `$D pull "$run" meal | jq -c --arg m "$m" '[.[] | select(.kind=="meal_estimation_status" and .record.mealId==$m) | .record.status] | last'` を読む。`estimating` を経て `estimated` になり、`dish` と `ingredient` の記録が `$m` に届く。鍵の無い回では `estimating` のまま
- **推定の失敗の理由を読む。** `$D call "$run" meal GET /v1/e2e/meals/$m/last-estimation-attempt --e2e` を送る。鍵の無い回では `{"lastEndedAttempt":{"result":"provider_error","errorType":"authentication_error"}}`（Anthropic まで届いた）
- **撮っておいた写真。** `entryMethod` を `picked` にして、食事と写真の控えを送る。同じく `estimating` に進む
- **料理の名前を直す。** 推定できた料理の ID を `d` として、`$D push "$run" meal "[{\"type\":\"update_dish\",\"dishId\":\"$d\",\"name\":\"親子丼（大盛り）\"}]"` を送る。`applied` で、取りに行くと `$d` の最後の `dish` の名前が変わっている
- **サブスクリプションを待っている。** `$D sign-in "$run" expired --as-of "$(date -u -d '-60 days' +%FT%TZ)"` のアカウントで撮った食事を送る。写真の控えを送ったあと、`meal_estimation_status` が `awaiting_subscription`（鍵が無くても確かめられる）
- **消す。** `$D push "$run" meal "[{\"type\":\"delete_meal\",\"mealId\":\"$m\"}]"` を送る。`applied` で、取りに行くと `$m` の変更が `meal_deletion` と `meal_estimation_status_deletion`（どちらも `record` は空）になる

## Gotchas

- 鍵の無い回の推定は、`authentication_error` の失敗を繰り返し、`estimating` のまま止まって見える。壊れたと読まない。結果は「確かめていない」と書き、merge のあとの `main-flow-on-development` に任せる
- 写真の控えは、食事より先に届いてもよく、消した食事の写真にも `204` を返す。`204` だけで写真が食事についたと読まず、推定の状態が `estimating` に進むかを見る
- 推定は Durable Object のアラームで進むので、送った直後の取りに行く要求にはまだ出ない。固定の時間でなく、状態が変わるまで読む
- 料理の名前を直すのは推定できた料理だけ。鍵の無い回では料理ができないので、この入口は確かめられない
