# 目標の設定と週の見直し（サーバー）

## 目標の設定の要求

- 目標の設定は、同期の外でその場で答える要求で進める。経路は `src/http/goal-setup-routes/`（`/v1/goal-setup/*`）、入口は `src/goal/domain/` の `previewGoalSetup`（目標の下見）・`proposeGoals`（目標案）・`assessCustomTargetWeight`（自分で決める目標体重）で、その人の Durable Object の同じ名前の RPC から呼ぶ。この3つは何も書かない。ただし、目標を決める要求と同じく、答える前にまだ見直していない週を見るので、見直しが要るときだけ週の見直しの行を書く（下の「週の見直し」）
- 見せる値（目標案、自分で決めた目標体重の評価、維持の目標体重と1日の目安）は `src/goal/domain/goal-offer/` の1か所で出す。目標案・自分で決める目標体重・目標を決める要求の3つの入口はどれもここを通り、目標を決める要求は見せる値を組み直さずに、端末が見せていた値と比べるだけにする（`assessGoalDecision`）
- どの要求も、計算の元（開始の日、今の目標、開始の日の体重の傾向、推定消費カロリー）を `src/goal/domain/goal-setup-basis/` の `resolveGoalSetupBasis` で要求のたびに出し直す。初めての目標では推定消費カロリーを逆算か式で出し、今の目標があれば今の推定（`ExpenditureEstimateStore.findCurrent`）を使う。目標案から先は同じ module の `resolveCompleteGoalSetupBasis` で、体重記録と推定消費カロリーが揃っていることを確かめ、減量・増量の計算の元（期限までの日数を含む）は `computeWeightChangeGoalInputs` で出す
- 断る要求（不具合のときだけ届く）は、形の誤りを 400、値の誤り（`GoalSetupRequestRejectedError` の `reason`）を 422 にして、本文の `code` に理由を入れ、受け口が Sentry に送る。エラーには理由と、誤っていた場所だけを持たせ、届いた値を載せない
- 目標の下見の「減量の案を1つでも出せるか」は、期限を選ぶ前に答えるので、受け付けるいちばん短い期限（`src/goal/domain/accepted-deadline/` の `acceptedDeadlineDays.minimum`）で確かめる
- 目標を決める要求（`POST /v1/goal-setup/decisions`、入口は `decideGoal`）が目標の行を書く（ほかに書くのは、下の「週の見直し」の、期限後の維持の目標を作る週の見直しを書く口だけ）。記録の変化を書く入口（`RecordChangeWriter`）の `run` の中で、要求の受け取り（`goal_decision_receipts`）を見て、同じ計算の元で見せる値を出し、端末が見せていた値と同じときだけ、目標を決めたことを書く口（`src/goal/domain/write-goal-decision.ts`。テストは Durable Object の置き場に当てる `src/goal/durable-object/write-goal-decision.test.ts`）で行の組を書く
  - 応答の `status` は3つ: 決めた `decided`、開始の日か見せていた値が違った `recalculated`（目標案の応答と同じ形の新しい案を返し、受け取りを書かない。開始の日がずれて期限が 28〜182 日の外に出たら、受け付けるいちばん近い日に寄せた期限の案を返し、端末はその期限を使い直す）、自分で決めた目標体重を受け付けない `custom_target_weight_rejected`。同じ要求の ID の再送は、書かずに、決めた目標から読み直した記録（`readGoalDecisionRecords`）で `decided` を返す
  - 目標・推定消費カロリー・1日の目安の行は、書く口を通してだけ書く。口は、表で守らない決まり（今の目標をいつも閉じて 0..1 に保つ、開始の日を今の目標より前にしない、推定の始まりは推定の行が無いときだけ、減量・増量で目標体重と開始の日の体重の傾向が等しくない、区分の値が一覧にある）を書く前に確かめて投げ、外部キーが指す行を先に書く
  - 決めたときだけ、PostHog に `goal_decision_recorded` を送る（利用状況の設定に従う。再送では送らない）。体重・目標体重・kcal の値は載せない

## 週の見直し

- 週の見直しと、達成・期限の日の確定は、端末の要求の中で行い、アラームは使わない。起こすのは次の要求だけで、ほか（送り切っていない送る要求、写真、見守る、セッション）では起こさない
  - 送り切った印（`isFinalBatch`）のある送る要求: 送った記録を当てたあと
  - 取りに行く要求: 取りに行く前（見直しで変えた記録を同じ応答で届けるため）
  - 目標の設定の4つの要求: 答える前。月曜に立て直すと、その月曜の見直しは前の目標に当たり、新しい目標はそのあとに決める
- 要求の中では、達成と期限の日の確定（`judgeGoalProgress`）を、まだ見直していない週（`reviewUnreviewedWeeks`）より先に判定する。期限の日の翌日の最初の要求で届いた期限の日以前の体重は、確定の前の達成として数える
- 週の区切りと今日は要求のタイムゾーンで決め、読めないタイムゾーンの要求では見ずに次の要求に任せる。週は古い順に1週ずつ、1週を記録の変化を書く入口の1つの `run` にする（次の週が、前の週に書いた推定と1日の目安を読む）
- 必要な速さ（維持の幅を含む）は、目標を立てたときと同じ式（`computeRequiredPace`）で出す。続いた週の数は残さず、見直すたびにずれの向きの並びから数える
- 期限後の維持には、今の減量・増量の目標の期限の日より後の最初の見直し（見送る週も含む）で、その週の見直しと同じ `run` の中で移る。推定は新しく出さず、見送った週は前の目標の最後の1日の目安を写す
- 週の見直し・達成・期限の日の確定の行は、それぞれの書く口（`writeWeeklyReview`、`writeGoalAchievement`、`writeGoalDeadlineConfirmation`）を通してだけ書く。表で守れない決まりは口が書く前に確かめて投げる。週の見直しを書く口のテストは、Durable Object の置き場に当てる `src/weekly-review/durable-object/write-weekly-review.test.ts`
- 見直しと目標の経過の PostHog の出来事は、`judgeGoalProgress` と `reviewUnreviewedWeeks` が返す（利用状況の設定で絞るのは、`server/AGENTS.md` の「層」の送る前の1か所）。体重・目標体重・kcal の値は載せず、差・日数・数・区分だけを載せる
- 見直しを起こす要求は、要求ごとのログに見直した週の数（`reviewedWeekCount`）を出す。見直しを起こさない要求では出さない
