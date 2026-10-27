# ios

nu-tori の iPhone アプリ（SwiftUI、ADR-0004）。

## 構成

- 画面を持たないロジックは、ローカルの Swift パッケージ `NuToriCore/` に置き、SwiftUI・UIKit・HealthKit・SwiftData を import しない。下の「端末で行うもの」の計算と判定と、送り待ちの判断がここに入る。Linux のエージェントと CI でも型検査とテストを回すため
- アプリの流れ（`RootModel`。開く・サインインする・サインアウトするで画面を替える、記録忘れの通知から開いた着き先、受け付けなかった1行、規約への同意のシート）と、目標の設定の流れを持つもの（`GoalSetupSession`）は、NuToriCore に `@Observable` のまま置き、Core のテストで確かめる。画面からの記録の編集は、画面が `UserEdit` を closure 1つ（`performEdit`）で渡し、`RootModel.perform(_:)` が受ける。編集を足すときは、`UserEdit` に case と後始末（`aftermath`）を足す
- アプリのターゲットだけが使う依存の版の正本は、ターゲットを持たないパッケージ `AppDependencies/` に置き、`NuToriCore/` の依存にしない。理由は `AppDependencies/Package.swift` の先頭、上げ方は `docs/agents/dependencies.md`
- 記録の種類（今は体重記録、アカウントの設定、食事、推定の状態、料理、料理ごとの推定の状態、材料、知らせ、いつもの時刻、体重の傾向、送った文章、送った文章の状態、返事、目標、1日の目安、推定消費カロリー、週の見直し、サブスクリプションの状態）ごとに、フォルダを切る。`NuToriCore/Sources/NuToriCore/`・`NuToriCore/Sources/NuToriAPI/`・`NuTori/`（アプリのターゲット）のそれぞれに `WeightRecord/`、`AccountSettings/` を置き、その種類だけにかかる型・判断・SwiftData のモデル・画面を入れる。テストのターゲットも同じフォルダ名でそろえる。同期の共通のもの（同期の働き、同期の置き場の型、送り待ち）は `Sync/`、タイムラインは `Timeline/` に残す。機能を第一の軸にする切り方を採らなかった理由は「[コードの置き方を、機能ごとに縦に切るかを決める](https://github.com/gn-t-k/nu-tori/issues/153)」の解決コメント
- 端末の SwiftData は2つの置き場に分ける（[ADR-0022](../docs/adr/0022-device-cache-and-pending-writes-in-separate-stores.md)）。`SwiftDataSyncStore` が両方を持つ
  - キャッシュ（`CacheStore`）: 記録（知らせ、いつもの時刻、体重の傾向、送った文章の状態、返事、目標、1日の目安、推定消費カロリー、週の見直し、サブスクリプションの状態を含む）、アカウントの設定、同期の状態（通し番号など）、ヘルスケアに書いた料理の控え（`CachedHealthDishWrite`。書いた料理を書き直さず、消えた料理をヘルスケアから消すため）。サーバーの写しなので移行を持たず、形が合わず開けないときは置き場ごと消して全部取り直す（取り終えるまでタイムラインは初回の取得と同じ読み込み中）。モデルは `CacheStoreSchema` に並べる
  - 送り待ち（`PendingStore`）: 送り待ちとヘルスケアの同期の進み具合。`PendingStoreMigrationPlan` の版つきのスキーマで移行し、版ごとのモデルの写し（`PendingStoreSchemaV1`・`PendingStoreSchemaV2` の中）を固める。形を変えるときは、写しを固めたまま次の版を足し、`docs/agents/ios-mac.md` の「置き場の移行を実機で確かめる」を開発者に頼む。送り待ちは「種類の名前＋中身」（`PendingEntry`）で持つので、種類を足しても形は変わらない
  - 送り待ちの箱（`SyncBox`）、記録の種類（NuToriCore の `CacheApplying`。キャッシュへの当て方の `apply`・`erase` を、種類ごとに1回だけ持つ）、登録簿（並びは NuToriCore の `RecordKindRegistry.init(ports:)` に、種類ごとに `PortedRecordKind` の1行。アプリは `AppRecordKinds.registry` で SwiftData の口を渡す）が同期の入口。種類はキャッシュの口（`KeyedRecordCache`・`SingleRecordCache`）に当て、アプリは SwiftData の adapter（`SwiftDataKeyedRecordCache`・`SwiftDataSingleRecordCache`・`SwiftDataWeightTrendCache`）を口の取り出し方（`AppRecordKinds.Ports`）で渡す。アプリのターゲットが種類ごとに持つのは、SwiftData の行と、行と記録の対応（`Cached…+Cache.swift`）だけ。それぞれの役割と種類の足し方は `docs/agents/sync.md`。メモリの箱は `NuToriTestSupport` の `SyncBoxMock`（キャッシュが `RecordCacheMock` のものを、テストが `SyncBoxMock.ok(...)`・`.error(...)` で作る）。`RecordCacheMock` は、種類ごとに NuToriCore のメモリの adapter（`MemoryKeyedRecordCache`・`MemorySingleRecordCache`）を持ち、同じ当て方が当たる
  - 種類の名前: NuToriCore の `RecordKindName`（enum。rawValue は送り待ちに保存するハイフンの書き方。`weight-record`、`account-settings`、`meal`、`meal-estimation-status`、`dish`、`dish-estimation-status`、`ingredient`、`notice`、`usual-weighing-time`、`weight-trend`、`sent-text`、`sent-text-status`、`subscription-status`、`ai-utterance`、`goal`、`daily-guide`、`expenditure-estimate`、`weekly-review`）で、送り待ち・変更・登録簿・読める種類を渡す。足すときは case を足す。SwiftData のモデルは文字列のまま持ち、読み書きの口で `RecordKindName` に変える（読めない名前の送り待ちは開くときに捨てて `storeRecovery` に残す）。サーバーの列挙（`server/openapi.json` の `RecordKindName`。snake_case）との対応は `RecordKindName.serverName` の switch だけに書き、`ServerRecordKindNames.names` と突き合わせる（`AppRecordKindsTests`）。保存した名前（rawValue）を変えると、送り待ちの置き場の移行が要る
  - 保存の順: 記録を作る・直すときは、送り待ちを先に保存し、キャッシュをそのあとに保存する。ヘルスケアの同期の進み具合は、送り待ちと同じ保存で書く。全消去は、送り待ちを1つの保存で空にしてから、キャッシュを空にする。送り待ちとキャッシュに書く道は箱の `apply` の1本で、ヘルスケアの取り込みと UI テストの準備もそこを通す。順と分け方は NuToriCore の `SyncBoxSaveOrder` に1回だけ書き、箱（`SwiftDataSyncStore`・`SyncBoxMock`）は置き場の操作だけを渡す
  - 置き場を分ける前の1つの置き場（`RecordStore`）は、更新して最初に開いたときに、送り待ちとヘルスケアの同期の進み具合を送り待ちの置き場へ移して消す（`LegacyRecordStore`）。開けない形のときは送り待ちを捨て、`HandledFailure.storeRecovery` として Sentry に送る
- 食事の写真のファイル（`MealPhotos`。置き場は `AppRuntime` が渡す）: 元の写真と送る縮小版は Application Support（バックアップの対象）に、この端末に元の写真が無い食事（ほかの端末で記録した、機種変更のあと）のために取りに行った縮小版は Caches に置く。取りに行った縮小版は、食事かアカウントを消すまで持ち、それより前にシステムが空けたら、次に見るときに取りに行き直す
- ファイルを足すとき、`project.pbxproj` は直さない（フォルダの同期で拾われる）
- `ios` の下を探すときは、Grep の道具か `git grep` を使う。`NuToriCore/.build` などのビルドの置き場が数 GB ある。ビルドの置き場は worktree ごとにできるので、worktree を並べて作業するときは、使い終えたものから消す
- 型検査の厳しさの設定は `NuToriCore/Package.swift`、`SharedRulesGenerator/Package.swift`、`project.pbxproj` の3か所にあるので、そろえる
- Bundle ID は変えない。App Store Connect に上げたあとは変えられず、サーバーの Sign in with Apple の `aud` もこの値を見る

## 端末で行うもの

ルートの `AGENTS.md` の「リポジトリ全体の決定」の基準に当たるものだけを端末で行う。今の一覧:

- 記録をまとめて見せるための計算: 材料の量からの栄養、材料から料理・食事への栄養の合計、料理の量を直したときの材料の量の比例、1日の丸・日のまとめの合計、週の振り返りの中身（日の並び・平均・何週目か・ペースと次の週の1日の目安の文。`WeekRecap`）、目標の画面の中身（今の目標のカード・推移のグラフの点・過去の目標。`GoalOverview`）、習慣トラッカー、日と週の区切り、体重の日の代表値、体重の傾向のグラフの中身（点・線・使い始めの区切り・添え書き・目標体重の線と縦軸の範囲）、日のまとめの体重の傾向の速さ、日のまとめの進行中の要約（あと何 kg・あと何日。`GoalProgress`）、日のまとめの目標の行（その日を含む目標のその日の状態で書く小さな文と、次の目標の行。`DaySummaryGoal`）、体重の画面の目標までの道のり（`WeightGoalPath`）、目標の状態（目標がない・進行中・期限より前に達成・期限が来た・期限後に選ばなかった。今の目標の記録から出す `GoalStatus`）
- その日の1日の目安の引き方: その日の食べた量を、どの1日の目安と比べるか（基準1。電波が無くても1日の丸と日のまとめを目安と比べて見せるため、キャッシュの目標と1日の目安の記録で引く）。NuToriCore の `DailyGuideForDay` の1か所で、手順と入力と期待値はサーバーと同じ（`docs/agents/shared-rules.md` の「その日の1日の目安」）
- ペース: 今の体重の傾向の動きのままで期限に目標体重へ届くか、維持では体重の傾向が目標体重の近くに収まっているか（基準1。電波が無くても1日の丸・日のまとめ・体重の画面・週の振り返りで見せるため、同期で届いた体重の傾向から出す）。NuToriCore の `Pace` の1か所で、手順と入力と期待値はサーバーと同じ（`docs/agents/shared-rules.md` の「ペース」）
- 記録忘れの判定: 記録忘れの通知の予約の計画（どの日のどの時刻に予約するか。予約と取り消しを含む）と、体重の知らせを出すか・答えるかの判断（基準3。アプリが開かれていないときや電波が無いときにも、ローカル通知で届け、取り消すため）。判断は NuToriCore の記録忘れの計画（`MissedWeightRecordPlan`）の1か所で、「記録した日」と日ごとの知らせの ID もここでだけ作る。判断と通知の置き直しの入口は記録忘れの見張り（`MissedWeightRecordWatch`）の1つで、次に知らせを出すかを決める時刻も見張りが持つ。アプリのターゲットは出来事（通知を押した、記録した、同期した、時計が変わった、など）を知らせ、待つときに見張りに時刻を聞くだけにする
- 目標を立てる知らせを出すか・答えるかの判断: 目標の記録も知らせも無いまま取りに行き終えたら、種類だけから作る ID の知らせを1つ出し、目標が決まったときに答える（基準1。電波が無くても、目標が無いことをその場で知らせるため）。判断は NuToriCore の目標を立てる知らせの番（`GoalSetupNoticeKeeper`）の1か所で、入口は `RecordSync` の同期の終わりと `respondToGoalSetupNotice()`
- 目標の設定の流れ: どのページを出すか、答えを残すこと、4つの要求をいつ出しどの答えを使うか（基準1・2。電波が無くても向きと期限に答えて止まり、自分で決める目標体重の答えを待つあいだも動かせるため）。NuToriCore の `GoalSetupFlow` の1か所で、要求は `NuToriAPIClient` の目標の設定の4つ、送り切る・体重を記録する・応答の記録を当てる・知らせに答えるは `GoalSetupRecords`（`RecordSync` が従う）に頼む。期限のチップと選べる幅（開始の日から両端を含めて 28〜182 日）は `GoalDeadlineChoices` が出す。幅の正本は `shared/accepted-deadline-days.json`（`docs/agents/shared-rules.md` の「受け付ける期限」）
- 入力の検証: 受け付ける値の範囲、体重の打ち間違いの判定
- 観測を始めてよいかの判定: PostHog を始めてよいか（利用状況を送るがオンで、初回の取得を終えた）。オフへの切り替えが電波が無くてもその場で効くため
- 選んだ写真のまとめ方: 複数枚を一度に選んだとき、撮影時刻が近いものを1つの食事にまとめる（基準1）
- 無料体験とサブスクリプションの今日での状態: 同期で届いたサブスクリプションの状態の日付と時刻を、端末の今と今日と比べ、無料体験中・サブスクリプション中・切れ・テストユーザーと、無料体験の残りの日数を出す（基準1・3。電波が無くても、日付が変われば残りの日数と切れたことを描くため）。NuToriCore の `SubscriptionStanding` の1か所で、残りの日数の数え方は `docs/agents/shared-rules.md` の「今は片側だけの決めごと」
- 無料体験とサブスクリプションの知らせを出す日: 無料体験のあと3日・最後の日・無料体験が終わった・サブスクリプションが終わった・無料体験が無いの5つを、どの日のタイムラインに置くか（基準1・3。サーバーは知らせを書かず、電波が無くても日付が変われば出すため）。NuToriCore の `SubscriptionNotice` の1か所
- 締め出しの記憶: サーバーが 426 を返したら、締め出されたことをそのときのビルド番号と一緒に覚え、開いたときに覚えたビルド番号が今と同じなら、要求を待たずに締め出された状態で始める（基準1。電波が無いと締め出されたことが見えず、古い版で記録を書き足してしまうため）。ビルド番号が変わっていたら、または 426 でない応答を受けたら忘れる。NuToriCore の `AppLockout`（置き場は `AppLockoutStore`）

材料の量の比例は端末だけが持ち、比例させた結果をサーバーに送る。目標と目安の計算、いつもの時刻の学習、写真と文章からの推定はサーバーで行い、端末は結果（材料の栄養の値まで）を受け取る。

- 1日の目安が変わった理由の種類は、サーバーが見直しに書いた主な理由をそのまま使い、何週もまとめて見直したときも端末で比べ直さない（`DailyGuideChangeReason`）
- 文に出すだけのサーバーの決まりの値（1日の目安の下限など）は、計算に使わないので `shared/` に置かず、`DailyGuide` などの定数に正本のサーバーの名前を添えて持つ。添え方と、`scripts/check` で値のずれを見つけることは `docs/agents/shared-rules.md` の「サーバーを正本にする写し」

## 対応する iOS

- 最低対応版を変えるときは、`project.pbxproj` と `NuToriCore/Package.swift` の2か所をそろえる（今の版の理由は「[iOS の最低対応版を 26 に下げる](https://github.com/gn-t-k/nu-tori/issues/86)」の解決コメント）
- SwiftData の保存は、メインのコンテキストでだけ行う。バックグラウンドの ModelActor で保存すると、iOS 26 では `@Query` がデッドロックすることがある
- iOS 27 からの API（`ResultsObserver`、`HistoryObserver` など）の代わりに書いたところには、置き換え先の API を1行のコメントで残す。最低対応版を上げたときに探して置き換えるため

## 身体データ

- 目標の設定の途中で手で入れた身体データは、端末の中だけに持ち、目標が決まったら捨てる
- ヘルスケアから読んだ身体データと使い始める前の摂取エネルギーも、端末の中では目標が決まった時点で捨て、置き場（SwiftData、UserDefaults）に書かない

## ヘルスケアの読み方

初めて目標を立てるときの許可と読み取りの入口は、NuToriCore の `GoalSetupHealthReader` の1つ。HealthKit に触れるのは `HealthStore` の実装（`HealthKitHealthStore`）だけで、選ぶ・除く・不明にする判断は `GoalSetupHealthReader` に置き、`HealthStoreMock` で確かめる。

- 許可: 向きを選んだ直後に、身長・生年月日・性別・歩数・摂取エネルギーの読み取りを求める。体重（読む・書く）と体脂肪率（読む）も同じ要求に入れる（ヘルスケアは、まだ求めていない種類だけを画面に出す）。まだ求めていない種類があるかは `hasUnrequestedAuthorization()` で聞く。許可を求める文（`project.pbxproj` の `INFOPLIST_KEY_NSHealth…UsageDescription`）は、「[仕様: 土台と体重](https://github.com/gn-t-k/nu-tori/issues/103)」の本文が正本
- 初期値の窓: 端末の今のタイムゾーンでの、今日を除く直前の 28 日
- 摂取エネルギー: 初期値の窓に入る使い始める前の日だけを読む。出どころごとの日の合計を量のサンプルの統計（`separateBySource`）で出し、1日ごとに一番多い出どころの値にする（足し合わせない。同じ食事を2つのアプリが書いていることがあるため）。食品の組をたどって数え直さない。nu-tori 自身の分と今日の分は除く。P・F・C は読まない
- 身体データ: 目標の下見で逆算できないと返ったときだけ読む。生年月日は満年齢にする（手で入れた生まれた年は、今年 − 生まれた年。`AgeInYears`）。性別は男性・女性のどちらかのときだけ使う。歩数は、初期値の窓の日ごとの値（出どころの重なりはヘルスケアの統計がならす）
- 読めなかった値は「不明」（nil、または日ごとの辞書にその日が無い）にし、0 にしない。期間を限った読み取り許可（iOS 27）の境界より前の日と、境界をまたぐ日は不明にする。身長・生年月日・性別が不明なら、足りない値として手で入れてもらう
- 読み取りの失敗は `HandledFailure.healthRead` で Sentry に送る。値は送らない

## API

- クライアントは、`server/openapi.json` から swift-openapi-generator で生成し、`NuToriCore/Sources/NuToriAPI/Generated/` にコミットする。`server/openapi.json` が変わったら `scripts/check ios --fix` で生成し直す（`scripts/check ios` が最新かを確かめる）。生成器は `OpenAPIGenerator/` のパッケージで動かし、アプリのビルドには入れない。設定は `OpenAPIGenerator/openapi-generator-config.yaml`
- 生成したコードは `internal` にし、アプリには `NuToriAPIClient` だけを見せる。経路を足したら、`NuToriAPIClient` にメソッドを足し、応答をアプリで扱う形（文書にある状態コードごとの enum）にして返す
- ビルド番号のヘッダー（`X-App-Build`、値は `CFBundleVersion`）と 426 は、生成したクライアントのミドルウェア（`AppBuildMiddleware`）で扱い、OpenAPI の各操作と経路ごとの enum には載せない。どの操作でも、426 なら応答の解釈より前に `AppBuildUnsupportedError` を投げ（生成したクライアントが `ClientError` に包むので、`isAppBuildUnsupported` で見分ける）、受け付けたかどうかを `AppBuildGate`（ビルド番号と知らせる先の組）の `reportVerdict` で `AppLockout` に知らせる。426 は想定した結果なので Sentry に送らず（`HandledFailure.reported`）、同期では送り待ちを残して `appBuildUnsupported` で止める。生成したクライアントを通さない要求（写真の縮小版を送る要求）にも、同じヘッダーを付け、応答を受け取ったら同じく知らせる（`MealPhotos.finishUpload`）。仕様の正本は [#223](https://github.com/gn-t-k/nu-tori/issues/223)

## 作業の分け方

チケットを切り分けるときは、`docs/agents/issue-tracker.md` の「iOS のチケットの分け方」を読む。

## 確かめる

`scripts/check` を通したうえで、変えたものを動かして確かめる。Mac で作業するときは `docs/agents/ios-mac.md` を読む。

- 書いたら、まず `scripts/check ios --lint --fix` で整形と Lint だけを回す（数秒〜20秒ほど。全部は4〜5分）。Swift の決まりのうち機械で見分けられるもの（`.swiftlint.yml` の `custom_rules`）はここで落ちるので、通してから全部を回す
- Linux で `swift` が無いときは、`scripts/install-swift` で入れる
- Linux では、アプリのビルドを CI の `ios-app` に任せる
- UI テストは、PR では CI で回さない。UI テストか画面の経路を変える PR は、PR の先頭のコミットで UI テストを回し、コミットと結果を PR の本文に書いてから merge する。Mac のセッションでは自分で `scripts/check ios-ui-test` を回す
- Linux のセッションでは、PR の先頭のコミットで CI の `ios-app`（アプリのビルド）が通るのを待ってから、次の2つを同時に始め、先に出た結果で進める。そのランの URL か Mac の結果を PR の本文に書く
  - `gh workflow run ios-ui-test.yml --ref <ブランチ>` を回す。PR の無いブランチでも回せる
  - 開発者に、そのコミットの SHA を添えて、Mac で `scripts/check ios-ui-test` を回すよう頼む。Mac で落ちたら、落ちたテストの名前と失敗の要約を貼ってもらって読む
  - CI の回が落ちたら、`.github/workflows/ios-ui-test.yml` が上げる成果物（失敗の要約とスクリーンショット）を `gh api repos/gn-t-k/nu-tori/actions/artifacts/<ID>/zip` で落として読む
  - main でだけ落ちたとき（Mac と CI で Xcode やシミュレーターの版がずれていることがある）は、`docs/agents/tooling.md` の「CI」

  **Why:** Mac に頼んでから返事を待つあいだ CI を回さず、8時間止まった（#586）。Linux ではアプリを組めないので、組めない直しが Mac で初めて見つかり、半日の往復になった

- UI テストはサーバーにつながない。API とサインイン済みの状態を差し替える（差し替えの置き場と切り替え方は `docs/agents/languages/swift.md` の「依存の差し替え」）。API とのつなぎは、`NuToriAPI` のテスト（トランスポートの差し替え）とサーバーのテストで確かめる

## 配布と実機の確認

- main の `ios/` が変わるたびに、Xcode Cloud がビルドして TestFlight の内部テストに配る。署名とビルド番号は Apple 側に任せ、証明書を GitHub に置かない
- ヘルスケア、カメラ、通知、写真の読み込みに触れた PR を出すとき、外部テストに出す前、Xcode Cloud の設定か `ci_scripts/` を直すとき、アプリのクラッシュを調べるときは、`docs/agents/ios-release.md` を読む
