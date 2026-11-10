# 体重記録

ユーザーが手で記録した体重と、ヘルスケアから取り込んだ体重がサーバーに届き、取りに行くとほかの端末にも届く。体重記録が変わると、体重の傾向が出し直される。直した記録は版が上がり、取り込み元で消した記録は消える。

## Sub-features

- `weight-create` 手で記録した体重記録が届く
- `weight-import` ヘルスケアから取り込んだ体重記録（入力元と体脂肪率つき）が届く
- `weight-update` 体重記録を直すと、版が上がって届く
- `weight-source-deleted` 取り込み元で消した体重記録が消える
- `weight-trend` 体重記録が変わると、体重の傾向が届く

## How to get to it (user POV)

- アプリで体重を入力して記録する。端末は `POST /v1/sync/writes` で `create_weight_record` を送る
- ヘルスケアの体重が取り込まれる。端末は `create_weight_record` を `imported` つきで送る
- アプリで体重記録を直す。端末は `update_weight_record` を送る
- ヘルスケアで、取り込んだ体重を消す。端末は `source_deleted_weight_record` を送る
- どの端末でも、開くと `GET /v1/sync/changes` で取りに行く

## Driving it with verify-server

Preconditions:

- `$D sign-in "$run" weight` で作ったアカウント

- **手で記録する。** `w=$($D uuid)` として、`$D push "$run" weight "[{\"type\":\"create_weight_record\",\"weightRecord\":{\"id\":\"$w\",\"weightKg\":60.5,\"measuredAt\":$(date +%s)000,\"timeZone\":\"Asia/Tokyo\"}}]"` を送る。出力の `[0].result` が `applied`
- **届いたかを読む。** `$D pull "$run" weight | jq -c '.[] | select(.kind=="weight_record" or .kind=="weight_trend") | {kind, record}'` を読む。`weight_record` の `id` が `$w`、`weightKg` が `60.5`、`version` が `1`。`weight_trend` の `days` に今日の日付（記録の `timeZone` の Asia/Tokyo での日付。UTC の `date` とは日がずれることがある）と `trendKg` がある
- **直す。** `$D push "$run" weight "[{\"type\":\"update_weight_record\",\"weightRecord\":{\"id\":\"$w\",\"weightKg\":60.0,\"measuredAt\":$(date +%s)000,\"timeZone\":\"Asia/Tokyo\",\"version\":2}}]"` を送る。`applied` で、取りに行くと `$w` の最後の `weight_record` が `weightKg` `60`、`version` `2`。体重の傾向の `trendKg` も `60` に出し直される
- **取り込む。** `i=$($D uuid)` として、`$D push "$run" weight "[{\"type\":\"create_weight_record\",\"weightRecord\":{\"id\":\"$i\",\"weightKg\":61.0,\"measuredAt\":$(date +%s)000,\"timeZone\":\"Asia/Tokyo\",\"imported\":{\"sourceAppName\":\"ヘルスケア\",\"sourceBundleId\":\"com.apple.Health\",\"healthkitSampleUuid\":\"$($D uuid)\",\"bodyFat\":{\"percentage\":25.0,\"healthkitSampleUuid\":\"$($D uuid)\"}}}}]"` を送る。`applied` で、取りに行くと `$i` の `weight_record` があり、`imported.bodyFat.percentage` が `25`
- **取り込み元で消す。** `$D push "$run" weight "[{\"type\":\"source_deleted_weight_record\",\"weightRecordId\":\"$i\"}]"` を送る。`applied` で、取りに行くと `$i` の変更が `weight_record_deletion`（`record` は空）になり、`weight_record` としては出ない

## Gotchas

- `update_weight_record` の `version` は、届いた `version` に 1 を足して送る。2 より小さいと `rejected`（`version_too_low`）になる。新しい版は、送った版と今の版に 1 を足した値の大きいほうになるので、届いた版のままでも 2 以上なら受け付けられ、版は上がる
- 直して版が 2 以上になった記録を `source_deleted_weight_record` で消そうとすると、記録は残り、`kept_corrected` が返る（`applied` でも `rejected` でもない）。消える手順は、直していない（版 1 の）取り込んだ記録で回す
- 取りに行く応答は、記録ごとに今の形が1つ出る。消した記録は `<種類>_deletion` の種類で出る
- 体重の傾向は、日ごとにいちばん早い記録を代表にして出す。直す手順は、取り込む前（その日の記録が `$w` だけのとき）に回さないと、`trendKg` が直した値にならない
- `weight_trend` の `recordId` はいつも同じ（全部 0 の UUID）で、毎回全体が出直す
