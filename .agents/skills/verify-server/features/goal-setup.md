# 目標の設定

ユーザーは目標の向き（減量など）を選び、目標の下見で何が出せるかを知り、期限を決めて目標案を受け取り、案の1つを選んで目標を決める。決めると、目標と1日の目安と推定消費カロリーが届き、前の週から使っていれば、次に取りに行ったときに週の見直し（または見送り）が届く。

## Sub-features

- `goal-preview` 目標の下見が、逆算できるか、身体データを添えれば案を出せるかを答える
- `goal-proposals` 期限と身体データで、ペースごとの目標案が出る
- `goal-custom` 自分で決める目標体重が、出せるかを答える
- `goal-decide` 目標を決めると、目標・1日の目安・推定消費カロリーが届く。同じ要求の ID の再送は同じ応答になる
- `goal-weekly-review` 前の週に決めた目標に、今週の月曜の週の見直しが届く

## How to get to it (user POV)

- アプリの目標の設定で向きを選ぶ。端末は `POST /v1/goal-setup/preview` を呼ぶ
- 期限と身体データを入れる。端末は `POST /v1/goal-setup/proposals` を呼ぶ
- 目標体重を自分で入れる。端末は `POST /v1/goal-setup/custom-target-weight` を呼ぶ
- 案を選んで決める。端末は `POST /v1/goal-setup/decisions` を呼ぶ
- 次に開いたとき。端末は `GET /v1/sync/changes` で週の見直しを取りに行く

## Driving it with verify-server

Preconditions:

- `doctor.sh "$run"` が全部 `ok`
- `$S/sign-in.sh "$run" goal` で作ったアカウントに、7日と1分前の体重記録を送ってある（体重記録の「手で記録する」の `measuredAt` を `$(date -d '-7 days -1 minute' +%s)000` にする）
- `asof=$(date -u -d '-7 days' +%FT%TZ)`、`body='{"sex":"female","heightCentimeters":160,"ageYears":35,"activity":{"type":"level","level":"standing"}}'`、`P() { $S/api.sh "$run" goal --as-of "$asof" POST /v1/goal-setup/$1 -H 'content-type: application/json' --data "$2"; }`（macOS の `date` は `-v-7d`）

- **下見。** `P preview '{"timeZone":"Asia/Tokyo","direction":"lose"}'` を送る。`{"canBackCalculate":false}`（食べた量の記録が無い）
- **身体データを添えた下見。** `P preview "{\"timeZone\":\"Asia/Tokyo\",\"direction\":\"lose\",\"bodyData\":$body}"` を送る。`canOfferLoseProposals` が `true`
- **目標案。** `props=$(P proposals "{\"timeZone\":\"Asia/Tokyo\",\"plan\":{\"direction\":\"lose\",\"deadlineOn\":\"$(date -d '-7 days +90 days' +%F)\"},\"bodyData\":$body}")` を送る。`direction` が `lose` で、`proposals` の `standard` が `offered`（ほかのペースは身体データしだいで出せないことがある。上の身体データでは3つとも `offered`）
- **自分で決める目標体重。** `P custom-target-weight "{\"timeZone\":\"Asia/Tokyo\",\"direction\":\"lose\",\"deadlineOn\":\"$(date -d '-7 days +90 days' +%F)\",\"targetWeightKg\":58,\"bodyData\":$body}"` を送る。`status` が `accepted` で、`dailyGuide` と `difficulty` が返る
- **決める。** 標準の案から要求を作る: `req=$(jq -c --argjson body "$body" --arg rid "$($S/uuid.sh)" '(.proposals[]|select(.pace=="standard")) as $s | {timeZone:"Asia/Tokyo",requestId:$rid,startedOn,choice:{type:"proposal",direction:"lose",deadlineOn,pace:"standard"},shown:{targetWeightKg:$s.targetWeightKg,dailyGuide:$s.dailyGuide},rejectedCustomTargetWeightCount:0,bodyData:$body}' <<< "$props")`。`P decisions "$req"` を送る。`status` が `decided`、`changes` の種類が `goal`・`daily_guide`・`expenditure_estimate` の順
- **再送。** `P decisions "$req"` をもう一度送る。初めと同じ応答
- **届いたかを読む。** `$S/pull.sh "$run" goal | jq -c '.[] | {kind} + (if .kind=="weekly_review" then {effectiveOn:.record.effectiveOn, deferral:.record.deferral} else {} end)'` を読む。`goal`・`daily_guide`・`expenditure_estimate` があり、`weekly_review` の `effectiveOn` が今週の月曜で、使い始めて1週に満たないので `deferral.reason` が `within_first_week`、`deferral.goalId` が決めた目標

## Gotchas

- `--as-of` を付けないと、今の時刻で決まり、開始の日が今週に入って週の見直しが届かない。時刻の差し替えは開発用の設定と確かめの秘密の値が揃ったときだけ効き、揃わなければ黙って今の時刻になる
- 身体データは計算に使ったら捨てられ、取りに行っても届かない。届かないことを失敗と読まない
- `shown` は、目標案で見せた値をそのまま送る。値を変えると、決めずに断られる
