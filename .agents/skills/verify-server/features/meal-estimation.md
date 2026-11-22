# 食事の記録と推定

ユーザーが食事を撮る、撮っておいた写真を選ぶ、文章で書いて送ると、サーバーで推定が進み、料理と材料が届く。推定の状態は、写真を待っている、推定中を経て、推定できた・推定できなかったなどになる。無料体験の終わったアカウントでは、推定を始めずサブスクリプションを待っているになる。推定でできた料理の名前を直せ、食事を消せる。

## Sub-features

- `meal-captured` 撮った写真の食事を送ると、写真を待っている → 推定中 → 推定できた、と進む
- `meal-picked` 撮っておいた写真の食事も同じく進む
- `meal-written` 文章の食事（食事と読み分けた送った文章）が推定まで進む
- `meal-awaiting-subscription` 無料体験の終わったアカウントの食事が、サブスクリプションを待っているになる
- `meal-photo-backup` 写真の控えを送り、ほかの端末から取りに行ける
- `meal-rename-dish` 推定でできた料理の名前を直す
- `meal-nutrition-label` 栄養成分表示が写った食事が、表示の値で記録される
- `meal-nutrition-label-rename` 材料がすべて栄養成分表示の料理の名前を直すと、推定し直さず、表示の材料がそのまま残る
- `meal-delete` 食事を消す

## How to get to it (user POV)

- アプリで食事を撮る。端末は `create_meal`（`entryMethod` `captured`）を送り、続けて `PUT /v1/meal-photos/{photoId}` で写真の控えを送る
- 入力欄の「写真」から撮っておいた写真を選ぶ。`entryMethod` が `picked` の `create_meal` と写真の控え
- 入力欄に食事を書いて送る。端末は `create_sent_text` を送り、読み分けで食事になると文章の食事ができる（送った文章は [送った文章と返事](./reply.md)）
- 写真を持たない端末で食事を見る。端末は `GET /v1/meal-photos/{photoId}` を呼ぶ
- 料理の名前を直す（`update_dish`）、食事を消す（`delete_meal`）
- 市販品と栄養成分表示を撮る（1枚に並べる、または同じ食事の別の写真）。送るものは撮った食事と同じ

## Driving it with verify-server

Preconditions:

- `$D sign-in "$run" meal` で作ったアカウント
- 推定できた、まで見るなら、`VERIFY_SERVER_ANTHROPIC_API_KEY` に開発用のワークスペースの鍵を渡して立てた回

- **撮った食事を送る。** `m=$($D uuid); p=$($D uuid); now=$(date +%s)000` として、`$D push "$run" meal "[{\"type\":\"create_meal\",\"meal\":{\"id\":\"$m\",\"eatenAt\":$((now-60000)),\"eatenAtUtcOffsetSeconds\":32400,\"sentAt\":$now,\"sentTimeZone\":\"Asia/Tokyo\",\"entryMethod\":\"captured\",\"photos\":[{\"id\":\"$p\"}]}}]"` を送る。`applied` で、取りに行くと `$m` の `meal_estimation_status` が `awaiting_photos`
- **写真の控えを送る。** `$D call "$run" meal PUT /v1/meal-photos/$p --body-file server/e2e/photos/oyakodon.jpg --content-type image/jpeg` を送る。状態コード `204`
- **写真の控えを取りに行く。** `$D call "$run" meal GET /v1/meal-photos/$p --out "$run/evidence/photo.jpg"` を送る。状態コード `200` で、`file "$run/evidence/photo.jpg"` が JPEG（端末が送った縮小版のまま）
- **JPEG でない中身を断る。** `printf 'JPEG ではない' > "$run/evidence/not-jpeg.bin"` として、`$D call "$run" meal PUT /v1/meal-photos/$($D uuid) --body-file "$run/evidence/not-jpeg.bin" --content-type image/jpeg` を送る。状態コード `415`
- **食事より先に届く写真の数の上限。** `$D sign-in "$run" photos` のアカウントで、`for i in $(seq 100); do $D call "$run" photos PUT /v1/meal-photos/$($D uuid) --body-file server/e2e/photos/oyakodon.jpg --content-type image/jpeg; done` を送る。どれも `204`。続けて同じ要求をもう1回送ると `429`。そのあと `create_meal` を先に送った写真の控えを送ると `204`
- **推定が進む。** 写真の控えが届くと `estimating` になる。5 秒おきに `$D pull "$run" meal | jq -c --arg m "$m" '[.[] | select(.kind=="meal_estimation_status" and .record.mealId==$m) | .record.status] | last'` を読む。`estimating` を経て `estimated` になり、`dish` と `ingredient` の記録が `$m` に届く。鍵の無い回では `estimating` のまま
- **推定の失敗の理由を読む。** `$D call "$run" meal GET /v1/e2e/meals/$m/last-estimation-attempt --e2e` を送る。鍵の無い回では `{"lastEndedAttempt":{"result":"provider_error","errorType":"authentication_error"}}`（Anthropic まで届いた）
- **撮っておいた写真。** `entryMethod` を `picked` にして、食事と写真の控えを送る。同じく `estimating` に進む
- **上限より長い名前に直す。** 推定できた料理の ID を `d`、`long=$(printf 'あ%.0s' $(seq 101))` として、`$D push "$run" meal "[{\"type\":\"update_dish\",\"dishId\":\"$d\",\"name\":\"$long\"}]"` を送る。`rejected` で理由が `out_of_range`、取りに行っても `$d` の名前は変わらない
- **料理の名前を直す。** `$D push "$run" meal "[{\"type\":\"update_dish\",\"dishId\":\"$d\",\"name\":\"親子丼（大盛り）\"}]"` を送る。`applied` で、取りに行くと `$d` の最後の `dish` の名前が変わっている
- **栄養成分表示の写った食事。** 評価のケース（`server/.scratch/nutrition-label/<ケース>/`。無ければ `scripts/cloudflare evals get` で落とす。リポジトリには入れない）のうち、`expected.json` の `target.type` が `meal` で `expected.type` が `labeled` のものを選ぶ。フォルダの `photo-*.jpg` をすべて `create_meal` の `photos` に並べ、それぞれ写真の控えを送る。推定できたら `$D pull "$run" meal | jq -c --arg m "$m" '[.[] | select(.kind=="dish" and .record.mealId==$m) | .record.id] as $ds | [.[] | select(.kind=="ingredient" and (.record.dishId | IN($ds[]))) | .record | {name, quantity, edibleGramsPerUnit, nutrientSource, nutrients}]'` を読む。表示の材料の `nutrientSource.type` が `nutrition_label` で、その材料の栄養を `docs/agents/shared-rules.md` の「栄養の合計」の数え方で出した値と `expected.json` の値の差が、kcal・P・F・C で 1、食塩相当量で 0.1 以内（評価の `judge-nutrition-label-run.ts` の `allowedDifferences` と同じ）で、料理の名前に `nameIncludes` のどれかが入っている
- **表示の料理の名前を直す。** 上の栄養成分表示の写った食事のうち、材料が表示の材料1つだけになった料理を `d` とし、`$D push "$run" meal "[{\"type\":\"update_dish\",\"dishId\":\"$d\",\"name\":\"〇〇の商品\"}]"` を送る。`applied` で、取りに行くと `$d` の最後の `dish` の名前が変わり、`$d` の `dish_estimation_status` は届かず、材料は名前を直す前と同じ ID で `nutrientSource.type` が `nutrition_label` のまま
- **サブスクリプションを待っている。** `$D sign-in "$run" expired --as-of "$(date -u -d '-60 days' +%FT%TZ)"` のアカウントで撮った食事を送る。写真の控えを送ったあと、`meal_estimation_status` が `awaiting_subscription`（鍵が無くても確かめられる）
- **消す。** `$D push "$run" meal "[{\"type\":\"delete_meal\",\"mealId\":\"$m\"}]"` を送る。`applied` で、取りに行くと `$m` の変更が `meal_deletion` と `meal_estimation_status_deletion`（どちらも `record` は空）になる。推定できた食事なら、その料理の `dish_deletion` と材料の `ingredient_deletion` も届く。名前を直して推定し直しを始めた料理なら `dish_estimation_status_deletion` も届く（材料がすべて栄養成分表示で推定し直さなかった料理と、直していない料理には届かない）

## Gotchas

- 鍵の無い回の推定は、`authentication_error` の失敗を繰り返し、`estimating` のまま止まって見える。壊れたと読まない。結果まで見るには、鍵を渡して立て直す（`SKILL.md` の「起動」）。鍵が読めないときは `SKILL.md` の「確かめられないとき」
- 写真の控えは、食事より先に届いてもよく、消した食事の写真にも `204` を返す。`204` だけで写真が食事についたと読まず、推定の状態が `estimating` に進むかを見る
- 24時間に受け取る写真の数の上限は、届くまでの要求が回数の歯止めで数分かかるので通さない。食事が届かないまま期限を過ぎた写真の控えの取り消しは、手元では時刻を動かせないので通せない（どちらも、確かめる場所は SKILL.md の「確かめられないとき」）
- `429` は、アカウントごとの回数の歯止め（1分に 120 回）でも返る。「食事より先に届く写真の数の上限」の項目は、新しいアカウントで1回だけ通し、やり直すときは別の名前でサインインし直す。101 回目より前に `429` が出たら、回数の歯止めと読む
- 推定は Durable Object のアラームで進むので、送った直後の取りに行く要求にはまだ出ない。固定の時間でなく、状態が変わるまで読む
- 栄養成分表示の項目は、本物のモデルの読み取りに頼るので、1回の外れで壊れたと読まない。読み取りの揺れは `server/evals/nutrition-label/` の評価で見る
- 料理の名前を直すのは推定できた料理だけ。鍵の無い回では料理ができない。この入口と「上限より長い名前に直す」に触れた変更で鍵が読めなければ、`SKILL.md` の「確かめられないとき」のとおり止まる
- 「上限より長い名前に直す」は「料理の名前を直す」より先に送る。名前を直して推定し直しを始めた料理（材料がすべて栄養成分表示の料理は始めない）は、推定し直しが終わるまで `awaiting_estimation` で断られ、`out_of_range` まで届かない
