# サーバーの LLM の流れ

推定・読み分け・返事（LLM の提供元を呼ぶアラームの流れ）と、その鍵、推定が読む成分表の働き方。パスは `server/` から数える。

## 鍵と提供元

- 推定の提供元（Anthropic）の API キーは、秘密の値 `ANTHROPIC_API_KEY` に置く。環境ごとの Anthropic のワークスペース（開発用は `nu-tori-development`、本番は `nu-tori-production`）のキーを、それぞれの環境に置く。`wrangler.jsonc` の `secrets.required` には両方の環境に書き、テストの値は `vitest.config.ts` にある（テストは提供元を偽物に差し替えるので、この値は本物に届かない）
- 読み分け（Claude Haiku 5.5。#423 で決めた）も、推定と同じワークスペースの `ANTHROPIC_API_KEY` で呼ぶ。費用の上限はワークスペースの月の上限で、前払いのクレジットは自動で補充する（額と知らせは `docs/agents/production-incidents.md` の「費用の知らせ」）。上限に届くか補充が失敗してクレジットが尽きるとすべての文章が会話になるので、読み分けの呼び出しの失敗を Sentry に送り、急増で知らせる
- Workers AI のつなぎ（`ai` の binding）と、環境ごとの AI Gateway は置いていない（#422 で作ったゲートウェイは、読み分けを Haiku 5.5 にしたので消す。#446）。Workers AI を呼ぶようになったら、両方の環境に `ai` のつなぎを書き、ルートの `AGENTS.md` のとおり環境ごとのゲートウェイを作って通し、そのときゲートウェイの設定（支出の上限、ログ、認証）をここに書く。ゲートウェイを名指さずに呼ぶと、ログがオンの `default` のゲートウェイができる

## 推定

- 推定はアラームで進める。入口は `src/estimation/domain/advance-estimations.ts`: 待っている予定から推定を始め、次に試みる時刻が来た推定の試みを書いてから（`begin-estimation-attempts.ts`）、提供元を呼び（`run-estimation-attempt.ts`）、結果を書く（`record-estimation-attempt-outcome.ts`）。次に試みる時刻（待ちを広げる式と、試みの時間の上限）はドメイン層の `compute-next-estimation-attempt-at` が出し、アラームで動かす仕事の並び（`src/domain/account-alarm-jobs.ts`）もそれでアラームを合わせる
- 推定の予定と結果（予定・見送り・推定・試み・結果・完了・断念）は、推定の書き込みの口（`src/estimation/domain/write-estimation-events.ts`）を通して書く（端末の書き込みの外では、記録の変化を書く入口がこの口の中身を呼ぶ）。書く置き場はこの口と入口にしか渡らず、口が書く前とあとの推定の状態を比べて変わった食事・料理にだけ推定の状態の変更を足すので、書く場所では足さない
- 予定と推定の対象は、食事（写真の推定）か料理（名前を直した・料理を足したときの推定し直し。`EstimationTarget`）。料理が対象の推定は、料理の今の値を ① に渡し、終わったら `apply-dish-estimation.ts` が当てる（料理を消していたら、届いた推定を捨てる）。回数・見送り・やり直し・アラームは食事が対象の推定と同じ流れに載る
- 推定の回数は、アカウントごとに1日 `maximumDailyEstimations`（15）まで。`beginEstimationAttempts` が、予定から推定を始める前に、予定の数える日（`counted_on`）の `estimations` を数え、上限なら見送る（`estimation_deferrals`、次の日の 0:00 の予定とつなぎ、PostHog の `estimation_deferred` の理由 `daily_limit`）。次の日の 0:00 は、ユーザーの最新のタイムゾーン（読めなければ食事を送ったときのもの）で `computeNextDayStart` が出し、その日の分に数える。日ごとの回数の行は持たず、食事を消しても推定の行は残るので回数は戻らない。テストは `src/estimation/http/testing/insert-counted-estimations.ts` で、食事につながらない推定を書いて回数を満たす
- 推定を始めるとき、予定の数える日でサブスクリプション切れ（`src/subscription-status/domain/is-subscription-expired/`）なら、回数より先に見て推定を始めず、保留（`estimation_holds`）を書く（PostHog の `estimation_deferred` の理由 `subscription_expired`）。いちばん新しい予定が保留の食事・料理の推定の状態は `awaiting_subscription`。保留の再開は `src/estimation/domain/resume-held-estimations.ts` が、使えるようになった食事・料理ごとに、数える日を今日・時刻を今にした新しい予定を足す。推定を始めるときと課金の仕事のアラームが呼び、買った取引を書くトランザクションも同じ推定の書き込みの口の中で呼ぶ
- 提供元（LLM）は、ドメイン層の型 `EstimationProvider`（`src/estimation/domain/estimation-provider.ts`）を、`src/estimation/durable-object/create-estimation-provider/` が作る。Durable Object は推定のたびにここから得る。本物は Anthropic の API（`@anthropic-ai/sdk`。再試行は SDK でなくドメイン層が持つので切る）で、`create-anthropic-estimation-provider.ts` が組む。モデルは Claude Sonnet 5（`request-structured-output.ts` の1か所）、思考は `thinking: { type: "disabled" }` で切り、`metadata.user_id` にアカウント ID の SHA-256 を入れ、構造化出力（`output_config.format`）で答えさせる。呼び出し1回の時間の上限は ① が 90 秒、② が 60 秒（試み全体の 3 分の中に収まる）。HTTP 400 は 400 の失敗、時間切れは時間切れの失敗、そのほかの SDK のエラーは提供元のエラー（`errorType` は応答のエラーの種類、無ければ `http_<状態コード>`、つなげなければ `connection_error`）、構造化出力が読めない・出力の上限で切れた・答えなかったは読めない応答の失敗（使ったトークンつき）にする。提供元の応答のテキストは残さない。差し替えの口はここ1つにし、テストは同じフォルダの mock で偽物に差し替える（料理あり・料理なし・確かめに通らない・答える前に待つは `mockCreateEstimationProviderOk`、エラー・400・時間切れ・② だけ落ちるは `mockCreateEstimationProviderError`）。提供元そのものの要求の組み立てと応答の読み取りは、Anthropic の API の手前（SDK の `fetch`）を差し替えて確かめる（`testing/stub-anthropic-api.ts`）
- ① には、材料の量と単位に加えて、食べた分の可食部の g の合計（`edibleGrams`）を答えさせ、1単位あたりの g はドメイン層が量で割って出す（`run-estimation-attempt.ts` の `composeDishes`）。量と1単位あたりを別々に答えさせると、重ねて答えたときに掛け算で桁が跳ねる（#517）。① の指示か答えの形を変えたら、`pnpm exec tsx evals/ingredient-grams/check-ingredient-grams.ts` を回し、材料の g がありうる範囲に収まるかを見る
- 栄養成分表示の値（①）と AI の推定の値（②）は、食べ物にありえない濃さなら確かめに通さない（`run-estimation-attempt.ts` の `isPossibleInFood`）。上限は基準 100 g あたりで、エネルギーが 1,200 kcal、g の項目が 200 g。基準の読み違いで桁が跳ねた答えを落とすためのもので、正しい記録をはじかない高さに置く: エネルギーは純粋な脂質（約 900 kcal）に栄養成分表示の許容差（±20%）を見込み、g の項目は、重さ（100 g）の倍にする（① が ml を g とみなすので、水あめのような重い液体は 100 ml あたり 120 g 近くになり、それを通すため）。基準が 0.2 g に満たない粒の表示は、丸めだけで上限を超えることがあり、そこは割り切る。材料の g そのものには上限を置かない（鍋ごとの記録や水 2 L は本物の記録で、ありえないと言える高さが無い）
- LLM の呼び出しの失敗の型は、推定・読み分け・返事で同じ1組にする（`src/domain/llm-call-error.ts`・`llm-call-bad-request-error.ts`・`llm-call-timed-out-error.ts`・`llm-call-invalid-response-error.ts`）。Anthropic の SDK の失敗をこの型に写すのは `src/durable-object/anthropic/catch-anthropic-failure.ts` の1か所だけにし、提供元を足すときもここを通す
- 提供元の失敗と、確かめに通らない応答は、試みの結果（`estimation_attempt_results.result`）にする。R2 と成分表の段で止まったら投げ、試みを結果の無いまま残して、途中で止まった試みとして数える
- アラームの中は受け口の要求ごとのログを通らないので、アラームが呼び出しごとに `route: "alarm"` のログを出す（試みごとの結果・失敗した段・提供元のエラーの種類）
- 試み1回分の中身（返った中身の確かめ、文章の食事のまとめ方と時刻の境目、① と ② の使用量の分け方、栄養の出どころ）は、`run-estimation-attempt.test.ts` が、偽の提供元（`src/estimation/domain/estimation-provider.mock.ts`。提供元を作る口の mock もこれを差す）と偽の写真の置き場を渡して直接確かめる。HTTP から動かす推定のテストは、つなぎ（記録・同期・出来事・ログに出ること）と予定（回数、見送り、やり直し、アラーム）に絞り、試みの中身の分岐を足さない
- HTTP から動かす推定のテストは、`src/estimation/http/testing/use-fake-clock.ts` で Date だけを先の時刻にして、アラームがひとりでに動かないようにし、`runDurableObjectAlarm` で動かす。やり直しは時計を進めてから動かす

## 読み分け

- 読み分けはアラームで進める。入口は `src/sent-text/domain/classify-sent-texts.ts`: 読み分けを待っている文章（読み分けの行が無い）を送った時刻の順に1つずつ提供元に読ませ、1つのトランザクションで読み分けの結果と送った文章の状態の変更を書く。食事なら文章の食事（入口 `written`、時刻は送った時刻、`sent_text_meals` に文章を持つ）を作って推定の予定に入れ、会話・決めかねる・呼び出しの失敗なら会話にして返事の依頼（きっかけ: 読み分け）を書く。`runAccountAlarm` は推定より先に読み分けるので、文章の食事の推定は同じアラームで始まる
- 読み分けは試みの行を持たず、やり直さない。呼んでいるあいだに止まった文章は行が無いまま残り、次のアラームで読み直す。読み分け待ちの文章があれば、次のアラームの時刻はその文章を受け取った時刻（過ぎているので、すぐ動く）
- 読み分けと返事の提供元（LLM）は、ドメイン層の型 `ConversationProvider`（`src/reply/domain/conversation-provider.ts`）を、`src/reply/durable-object/create-conversation-provider/` が作る。差し替えの口はここ1つにし、テストは同じフォルダの mock で偽物に差し替える（食事・会話・決めかねると返事は `mockCreateConversationProviderOk`、読み分けか返事の呼び出しの失敗は `mockCreateConversationProviderError` の `failingCall`）。本物は Anthropic の API（推定と同じく SDK の再試行は切る）で、`create-anthropic-conversation-provider.ts` が組む。読み分けは Claude Haiku 5.5（要求は `create-haiku-classification-request.ts`、基準の文面は `classification-criteria.ts`。どれも評価 `server/evals/classify` で確かめたので、変えたら回し直す）に、思考を切り、`metadata.user_id` にアカウント ID の SHA-256 を入れ、構造化出力で「食事」「会話」「決めかねる」の1つを答えさせる。呼び出し1回の時間の上限は 30 秒。失敗はどれも会話になるので `LlmCallError` の `errorType` で分けるだけにする（応答のエラーの種類、無ければ `http_<状態コード>`、つなげなければ `connection_error`、時間切れは `timed_out`、出力の上限で切れた・答えなかった・読めないは `invalid_response`）。提供元そのものは、推定と同じく SDK の `fetch` を差し替えて確かめる。返事の提供元は下の「返事」

## 返事

- 返事はアラームで進める（`runAccountAlarm` が読み分け・推定のあとに呼ぶ）。入口は `src/reply/domain/advance-replies.ts`: 待っている依頼から返事の生成を始めて試みを書き（`begin-reply-attempts.ts`）、応える文章の送った順に1つずつ文脈を読んで提供元を呼び（`run-reply-attempt.ts`。先に作った返事をあとの文章の窓に入れるため並べない）、結果を書く（`record-reply-attempt-outcome.ts`）。次に試みる時刻は推定と同じ式（`src/domain/compute-next-attempt-at.ts`）で、試みの時間の上限は `reply-attempt-time-limit-ms.ts`
- 返事の流れの出来事（依頼・きっかけ・回数切れ・生成・試み・結果・返事・作れなかった）は、返事の書き込みの口（`src/reply/domain/write-reply-events.ts`）を通して書く（端末の書き込みの外では、記録の変化を書く入口がこの口を呼ぶ）。口は、表で守らない決まり（依頼は会話と読み分けた文章にだけ、回数切れと生成・返事と作れなかったはどちらか1つ）を書く前に確かめて投げ、書く前とあとで送った文章の状態を比べて変わった文章にだけ状態の変更を、返事を書いたら返事の変更を足す。依頼ときっかけのサブセットは、口の `request` で一緒に書く（きっかけは依頼の型の `trigger` で1つ）
- 依頼の数える日でサブスクリプション切れなら、生成を始めず止め（`reply_request_subscription_halts`）を書く。回数切れと同じく買っても再開せず、応答の状態 `halted` の理由（`daily_limit`・`subscription_expired`）で見分ける
- 回数は1日 `maximumDailyReplyGenerations`（10）。生成を始めるときに、依頼の数える日の生成を数え、上限なら提供元を呼ばずに回数切れにする（翌日に回さない）。テストは `src/reply/http/testing/insert-counted-reply-requests.ts` で回数を満たす
- 指し示す食事は、文脈で ID を付けた食事（今日と昨日の食事、記録の印の食事）のうち在るものだけを通し、ほかは読めない応答にしてやり直す
- 返事の本物の提供元は Claude Sonnet 5.5 を流す形で呼ぶ（`generate-reply-with-sonnet.ts`）。要求は `create-sonnet-reply-request.ts`（指示を system に、文脈の窓・記録の値・新しい発言の文の塊をユーザーのメッセージに並べ、窓のあとにキャッシュの印。思考は `thinking: { type: "between_tools" }` で切る。Sonnet 5.5 は `disabled` を 400 で断る）、指示の文面は `reply-instructions.ts`（評価 `server/evals/reply` のすべての場面で確かめた。指示・文脈の文面・要求を変えたら `pnpm run evals:reply` を回し直し、すべて通るまで直す）、答えは構造化出力の `{ body, mealIds }`。流れてきた JSON から本文のできた分だけを読み（`read-streamed-reply-body.ts`）`onText` に渡す。時間の上限は試みの signal だけ。400 は状態コードで見分けて 400 の失敗、出力の上限で切れた・答えなかった・形が違うは読めない応答、流れが終わりの出来事なしに閉じたら提供元のエラー（`stream_ended`）。提供元そのものは SDK の `fetch` を差し替え、流す応答は `testing/reply-with-text-stream.ts` で作って確かめる
- 見守る要求（`GET /v1/sent-texts/{sentTextId}/reply-stream`）は、Durable Object の RPC が返す SSE のバイトの流れを、受け口の Worker がそのまま `text/event-stream` で返す。つないでいる要求と、試みが流している途中の文は、Durable Object の実体のメモリ（`src/reply/domain/create-reply-watchers.ts`）にだけ持ち、記録に残さない。返事はアラームが作るので、端末が切れても最後まで作る。提供元は `generateReply` の `onText` に本文のできた分を渡し、アラームは読み分け・生成の開始・試みの結果のあとに `refresh` で結果を送る。出来事の形は `src/http/reply-stream-routes/reply-stream-event-schema.ts`

## 成分表のデータファイル

- 成分表のデータファイル（`src/domain/food-composition/food-composition-table.json`）は、文部科学省の本表の Excel から `scripts/build-food-composition-table.ts` が作る。手で書き換えず、成分表の版を上げるときや読み方を直したときに、`server/` で `pnpm exec tsx scripts/build-food-composition-table.ts` を回して作り直す。出典はファイルの `source`
- 栄養の項目の名前は `shared/nutrients.json`、成分表の列との対応は `src/domain/food-composition/nutrient-source-columns.ts`。項目を足すときは JSON に1行足し、対応を足して、データファイルを作り直す
