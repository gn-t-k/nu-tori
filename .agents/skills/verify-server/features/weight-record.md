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

- `doctor.sh "$run"` が全部 `ok`
- `$S/sign-in.sh "$run" weight` で作ったアカウント

- **手で記録する。** `w=$($S/uuid.sh)` として、`$S/push.sh "$run" weight "[{\"type\":\"create_weight_record\",\"weightRecord\":{\"id\":\"$w\",\"weightKg\":60.5,\"measuredAt\":$(date +%s)000,\"timeZone\":\"Asia/Tokyo\"}}]"` を送る。`results[0].result` が `applied`
- **届いたかを読む。** `$S/pull.sh "$run" weight | jq -c '.[] | select(.kind=="weight_record" or .kind=="weight_trend") | {kind, record}'` を読む。`weight_record` の `id` が `$w`、`weightKg` が `60.5`、`version` が `1`。`weight_trend` の `days` に今日の日付と `trendKg` がある
- **取り込む。** `i=$($S/uuid.sh)` として、`weightRecord` に `"imported":{"sourceAppName":"ヘルスケア","sourceBundleId":"com.apple.Health","healthkitSampleUuid":"<uuid.sh の値>"}` を足した `create_weight_record` を、`id` を `$i` にして送る。`applied` で、取りに行くと `$i` の `weight_record` がある
- **直す。** `$S/push.sh "$run" weight "[{\"type\":\"update_weight_record\",\"weightRecord\":{\"id\":\"$w\",\"weightKg\":60.0,\"measuredAt\":$(date +%s)000,\"timeZone\":\"Asia/Tokyo\",\"version\":2}}]"` を送る。`applied` で、取りに行くと `$w` の最後の `weight_record` が `weightKg` `60`、`version` `2`。体重の傾向の `trendKg` も `60` に出し直される
- **取り込み元で消す。** `$S/push.sh "$run" weight "[{\"type\":\"source_deleted_weight_record\",\"weightRecordId\":\"$i\"}]"` を送る。`applied` で、取りに行くと `$i` の変更が `weight_record_deletion`（`record` は空）になり、`weight_record` としては出ない

## Gotchas

- `update_weight_record` の `version` は、直したあとの版（届いた `version` に 1 を足した値）。届いた版のままで送ると `rejected`（`version_too_low`）になる
- `push.sh` は、書き込みが `rejected` でも状態コード 200 で 0 を返す。`results[].result` を読む
- 取りに行く応答は、記録ごとに今の形が1つ出る。消した記録は `<種類>_deletion` の種類で出る
- `weight_trend` の `recordId` はいつも同じ（全部 0 の UUID）で、毎回全体が出直す
