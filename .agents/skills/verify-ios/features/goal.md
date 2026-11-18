# 目標と週の振り返り

目標の無いユーザーは、タイムラインの目標を立てる知らせから向き・期限・目標案を選んで目標を決め、今日の丸と日のまとめが1日の目安と比べる形になる。目標のあるユーザーは、月曜のタイムラインに振り返りのカードと1日の目安の変更の知らせを受け取り、週の振り返りと目標の画面を開ける。目標の画面で目標を切り替えられる。

## Sub-features

- `goal-decide` 知らせから減量の標準の案で目標を決めると、決めたカードが出て、今日の丸と日のまとめが1日の目安と比べる形になる
- `goal-decide-maintain` 知らせから維持を選ぶと、保つ体重と1日の目安の値の行が出る
- `goal-weekly-review` 月曜のタイムラインの振り返りのカードから週の振り返りを開く
- `goal-screen` 左上の入口から目標の画面を開き、今のカード・推移のグラフ・週の振り返りへの入口が出る
- `goal-next` 目標を達成したあと、日のまとめの「次の目標を選ぶ」（`day-summary-next-goal`）で目標の設定のカードをタイムラインに広げる
- `goal-switch` 目標の画面で目標を切り替えると、目標の設定のカードを目標の画面にだけ広げる

## How to get to it (user POV)

- タイムラインの目標を立てる知らせの「始める」（`goal-setup-start`）を押し、向き（`goal-setup-direction-lose` など）、期限（`goal-setup-next`）、目標案（`goal-setup-proposal-standard` など）と進み、「この目標で始める」（`goal-setup-proposal-start`）で決める
- 月曜に開き、タイムラインの振り返りのカード（`weekly-review-card`）を押す
- タイムラインの左上の目標（`goal-link`）を押す。日のまとめの目標の行と、体重の画面の目標からも開く
- 目標の画面の「目標を切り替える」（`goal-switch`）を押す

## Driving it with verify-ios

Preconditions:

- なし（場面が、目標の無いアカウント、または先週の月曜に立てた目標を見直したアカウントを作る）

- **目標を決める。** `$S/ui-test.sh DecideGoalFromNoticeBackCalculatedUITests` の `test_知らせから減量の標準の案で目標を決めると決めたカードと目安と比べる丸になること`。目標案のあと「目標を決めました」と 69.2 kg のカードが出て、今日の丸の読み上げに「1日の目安 1,850 kcal」が付き、食べた日の日のまとめが「/ 1,850 kcal」と比べる
- **維持を選ぶ。** 同じクラスの `test_知らせから維持を選ぶと保つ体重と1日の目安の値の行が出ること`。「72.0 kg を保つ」と「1日の目安」2,250 kcal の行が出る
- **週の振り返りと目標の画面。** `$S/ui-test.sh OpenWeeklyReviewAndGoalFromMondayTimelineUITests`。振り返りのカード（9月28日〜10月4日）と変更の知らせが出て、カードから週の振り返り（P・F・C の平均の「C 炭水化物」まで）が開き、戻って左上から目標の画面（今のカード、推移のグラフ、週の振り返りへの入口）が開く
- **目標の画面へのほかの入口。** `$S/ui-test.sh OpenGoalFromDaySummaryAndWeightScreenUITests`。目標を達成した月曜に、日のまとめの目標の行から目標の画面が開く。タイムラインに戻って日のまとめを開き直し、「次の目標を選ぶ」（`day-summary-next-goal`）を押すと、タイムラインに目標の設定のカード（`goal-setup-flow`）が広がる。体重の画面の「目標 ›」から開いた目標の画面は、戻ると体重の画面に戻る
- **目標を切り替える。** `$S/ui-test.sh SwitchGoalOnGoalScreenUITests`。目標の設定のカード（`goal-setup-flow`）が目標の画面に広がり、タイムラインには描かれず、目標の画面を開き直すと広げたまま
- **手で見るとき。** 目標を決める流れは `$S/launch.sh "$run" signed-in goal-setup`、週の振り返りと目標の画面は `$S/launch.sh "$run" signed-in weekly-review UI_TEST_NOW=2026-10-05T09:00`

## Gotchas

- 目標案と1日の目安の値は偽の同期サーバーの決めた値。サーバーの計算は `verify-server` の [目標の設定](../../verify-server/features/goal-setup.md) で確かめる
- 週の振り返りの場面は、時計を 9:00（知らせの時刻のあと）にして開く。既定の 6:30 では UI テストと同じ画面にならない
