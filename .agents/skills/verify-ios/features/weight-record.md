# 体重記録

ユーザーは入力欄の体重か、知らせの時刻を過ぎたタイムラインの体重の知らせから体重を記録し、記録はすぐタイムラインに出る。体重の行から体重の画面に潜って値を直せる。電波が無くても記録は出て、送り待ちの印が付く。サーバーが受け付けなかった記録には1行が出る。ヘルスケアの体重は取り込まれてタイムラインに並ぶ。

## Sub-features

- `weight-record-composer` 入力欄の体重のシートで記録すると、タイムラインに出る
- `weight-record-notice` 知らせの時刻を過ぎて今日の記録が無いと、タイムラインに体重の知らせが出て、その中で記録できる
- `weight-correct` 体重の画面で直すと、タイムラインの値が変わる
- `weight-offline` 電波が無くても記録した体重がタイムラインに出て、送信待ちと読み上げる
- `weight-rejected` サーバーが受け付けなかった記録について1行出る
- `weight-health-import` ヘルスケアの体重が、取り込み元の名前つきでタイムラインに出る

## How to get to it (user POV)

- タイムラインの下の入力欄の体重（`composer-weight`）を押し、シートのステッパー（「0.1 kg 減らす」など）で値を合わせて、シートの右上の「記録」を押す
- 知らせの時刻（いつもの時刻が無ければ 8:00）を過ぎた朝に開き、タイムラインの体重の知らせ（`weight-notice`）の「記録」（`weight-notice-record`）を押す
- タイムラインの体重の行（`weight-row`）を押して体重の画面に潜り、「直す」で値を打って「完了」を押す
- ヘルスケアで体重を量る。アプリを開くと取り込まれる

## Driving it with verify-ios

Preconditions:

- なし（場面が、昨日 72.6 kg の記録のあるサインイン済みのアカウントを作る）

- **入力欄から記録する。** `$S/ui-test.sh RecordWeightFromComposerUITests`。72.6 kg から 0.2 kg 減らして記録すると、タイムラインに 72.4 kg が出て、シートが閉じ、受け付けなかった1行は出ない
- **入力欄から記録する（手で）。** `$S/launch.sh "$run" signed-in previous-day` で開き、`wait_for_ui` で `composer-weight` を待って `shot.sh "$run" weight-before`。今日の丸（`ring-2026-10-05`）の値が「体重の記録なし」。`composer-weight` を押し、シートの「0.1 kg 減らす」を2回押して、シートの「体重」の値が 72.4 kg になったら、シートの「記録」を押す。`wait_for_ui` で「記録」が `gone` になるのを待ち、`shot.sh "$run" weight-recorded`。タイムラインに昨日の「7:12 72.6 kg」と今日の「6:30 72.4 kg」の `weight-row` が並び、今日の丸の値が「体重の記録あり」になり、`rejected-weight-line` は無い
- **知らせから記録する。** `$S/ui-test.sh WeightNoticeAfterNoticeTimeUITests`。9:00 に開くとタイムラインに体重の知らせが出て、その中の「記録」で記録すると知らせが消え、入力欄の体重（`composer-weight`）はある
- **直す。** `$S/ui-test.sh CorrectWeightFromWeightScreenUITests`。体重の画面で 70.0 にすると、体重の画面に 70.0 が出て、戻ったタイムラインに 70.0 kg が出て 72.4 kg が無い
- **電波が無いとき。** `$S/ui-test.sh RecordWeightOfflineUITests`。記録した 72.4 kg の行が出て、その行の読み上げの最後に「送信待ち」が付き、届いている昨日の 72.6 kg の行には付かない
- **受け付けなかったとき。** `$S/ui-test.sh RejectedWeightRecordUITests`。`rejected-weight-line` の1行が出て、72.6 kg は残る
- **ヘルスケアの取り込み。** `$S/ui-test.sh ImportedHealthWeightAfterPullUITests`。初回の取得のあとに 68.0 kg の行が「体重計アプリ」と一緒に出る

## Gotchas

- タイムラインの体重の知らせ（知らせの時刻を過ぎた場面）にもステッパーと「記録」があるので、手で押すときは `snapshot_ui` の並びでシートの中のものを選ぶ。`snapshot_ui` には、シートの入れ物の `weight-entry-sheet` は出ない
- 手で記録した記録の時刻は、止めた時計の時刻（既定は 6:30）になる
- 手で記録したあと、送った記録がサーバーに届いたかは偽の同期サーバーでは分からない。サーバーの側は `verify-server` の [体重記録](../../verify-server/features/weight-record.md) で確かめる
- 本物のヘルスケアへの書き込みと読み取りは差し替えている。ヘルスケアに触れた PR は `docs/agents/ios-release.md` のとおり実機で確かめる
