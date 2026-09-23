# FoodNoms・MacroFactor とヘルスケア（HealthKit）のデータのやりとり

調査日: 2026-09-23（同日に本文で再確認）
対象: `docs/ui-design/0001-first-release/00-behavioral-scenarios.md` の S2-2・S5-5 の【要調査】

> **確認の方法と限界**
> - FoodNoms の公式ヘルプ・公式ブログ（foodnoms.com）、MacroFactor の公式ヘルプ（help.macrofactorapp.com）・公式ブログとリリースノート（macrofactor.com）、両アプリの App Store ページ（apps.apple.com、説明文とバージョン履歴）、Apple の HealthKit ドキュメント（developer.apple.com）の**本文を直接取得して読んだ**。本文で確かめた主張は「本文で確認」と書く。
> - MacroFactor のヘルプ記事「Integrations」の対応表は画像で掲載されている。画像を開いて読んだ。
> - 本文の記述から推し量ったものは「本文からの読み取り」と書き、何から読み取ったかを添える。
> - 本文や関連ページを探しても記述が無かったものは「本文を探したが記述なし」と書く。実機での確認はしていない。
> - FoodNoms の変更履歴ページ（https://foodnoms.com/changelog/ ）は 404 で、もう存在しない。変更履歴は App Store のバージョン履歴で代わりに確認した。App Store のバージョン履歴は取得時点（2026-09-23）で表示されていた範囲（2026.6 以降）しか読めていない。
> - 二次情報（レビュー記事、Reddit など）は使っていない。

## 結論の要約

- **S2-2（過去の体重・食事量から初期消費量を推定）は、条件付きで成り立つ。**
  - 体重: FoodNoms（2026 年夏のリリース以降）も MacroFactor もヘルスケアに体重を書き込む（本文で確認）。nu-tori は bodyMass を読めば過去の体重を得られる。
  - 食事量: FoodNoms は記録した食事の栄養を、MacroFactor はカロリー・マクロ・対応する微量栄養素を、ヘルスケアに書き込む（本文で確認）。ただしどちらも書き込みは設定で有効にする必要があり、**有効にしていなかった期間の分はヘルスケアに無い可能性がある**。FoodNoms には「Apple Health への再書き出し（re-export）」の機能があることがわかった（本文で確認）が、どこまでさかのぼるかは本文を探したが記述なし。
  - FoodNoms の無料版で記録できるのはカロリーとマクロだけで、ビタミン・ミネラル・水分・ナトリウムなどの記録は有料の Foodnoms+ の機能（本文で確認）。無料ユーザーのヘルスケアにはビタミン・ミネラルが入っていないと考えられる（本文からの読み取り）。
  - 両アプリが同じ食事を書き込んでいると、合計が二重になる。nu-tori は出どころ（`sourceRevision`）ごとに分けて集計し、1日ごとに1つの出どころを選ぶ必要がある。
  - iOS 27 から、ユーザーは読み取りを「期間を限って」許可できる。nu-tori はその境界より前を「データなし」ではなく「不明」として扱う必要がある（本文で確認）。
- **S5-5（nu-tori → ヘルスケア → MacroFactor）は成り立つ。**
  - MacroFactor は、ヘルスケアにある「その日の」カロリー・マクロ・微量栄養素を取り込む。別の記録アプリを使いながら MacroFactor のコーチングを受ける使い方（BYOFL: bring your own food logger）を想定していると公式に書かれている（本文で確認）。
  - **取り込んだ栄養は消費量の推定に使われる。** 公式ヘルプの消費量の記事に「摂取カロリーは、MacroFactor で食事を記録するか、同期している別の出どころから栄養を取り込むかのどちらかで得る」とある（本文で確認。前回は「直接の記述は未確認」だった）。
  - 取り込むのは**日ごとの合計**で、食品や食事の単位では取り込まない。取り込んだ値は Food Log ではなく Nutrition ページに出る（本文で確認）。
  - 優先順位は「手入力 > MacroFactor の Food Log > ヘルスケア」で、変更できない。**その日に MacroFactor の手入力か Food Log の記録が1件でもあると、その日のヘルスケアからの同期は行われない**（本文で確認。前回未確認だった「日単位で切り替わるか」は、日単位と確認）。
  - 過去分は、連携をつないだ時点から 30 日前までを取り込む（本文で確認）。

## 問い1: FoodNoms はヘルスケアに何を書き込み、何を読み込むか

### 書き込み

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 書き込みの有無 | 記録した食品の栄養をヘルスケアに保存できる。設定の Data & Integrations → Apple Health で「栄養データの書き込み」を有効にする | 本文で確認 | https://foodnoms.com/help/writing-to-health |
| 無料か有料か | ヘルスケアへの書き出し（export）は無料版に含まれる。無料版は「Export Only」、Foodnoms+ は「Import & Export」 | 本文で確認 | https://foodnoms.com/help/free-vs-plus 、https://foodnoms.com/plus |
| 書き込む栄養 | 「食事エントリが持っている栄養だけ」を書き込む。値が無い栄養は書き込まない | 本文で確認 | https://foodnoms.com/help/writing-to-health |
| 栄養の範囲 | App Store の説明: ヘルスケアと読み書きするのはカロリー、マクロ、ビタミン、ミネラル、水分、カフェインなど | 本文で確認 | https://apps.apple.com/us/app/nutrition-tracker-foodnoms/id1479461686 |
| 無料版で記録できる栄養 | 無料版はカロリーとマクロ。水分・ナトリウム・食物繊維・正味炭水化物・カフェイン・アルコール・ビタミン・ミネラルの記録は Foodnoms+。このため無料ユーザーが書き込むのは実質カロリーとマクロと考えられる | 前半は本文で確認、後半は本文からの読み取り | https://foodnoms.com/help/free-vs-plus 、https://foodnoms.com/plus 、App Store の説明 |
| 食事単位か合計か | 前回の根拠（変更履歴の「"Other" の食事タイプを Apple Health に保存すると深夜0時になる問題を修正」）は、変更履歴ページが 404 になっていて本文で確認できなかった。App Store のバージョン履歴 2026.9 に「Apple Health の日ごとの栄養合計が、記録した食品エントリの合計より少なくなることがある問題を修正」とある。エントリごとに書き込み、ヘルスケア側で日の合計になると読めるが、断定できる記述ではない。なお「エントリの時刻（timestamps）」は Foodnoms+ の機能 | 本文を探したが明確な記述なし（読み取りのみ） | App Store のバージョン履歴、https://foodnoms.com/help/free-vs-plus |
| HKCorrelation（food）を使うか | 本文を探したが記述なし | 記述なし | — |
| 過去分の書き出し | App Store のバージョン履歴 2026.12 に「Health の設定画面をすぐ離れると Apple Health への再書き出し（re-exporting）が始まらない問題を修正」とある。ヘルスケア設定に再書き出しの機能があることは確かだが、対象期間（有効化前の全履歴か）は本文を探したが記述なし | 機能の存在は本文で確認、範囲は記述なし | App Store のバージョン履歴 |
| Mac で記録した分 | Mac は直接ヘルスケアにアクセスできない。iPhone に同期された時点でヘルスケアに保存される | 本文で確認 | https://foodnoms.com/help/writing-to-health |
| 体重 | 体重記録を追加。体重はヘルスケアと**双方向**で同期する。Foodnoms で記録した体重はヘルスケアに保存される | 本文で確認 | https://foodnoms.com/news/2026-summer-update 、https://foodnoms.com/help/track-weight |
| 体重記録の追加時期 | 公式ブログは「version 2026.8」（2026-07-27 付）での追加と書く。App Store のバージョン履歴では体重記録は 2026.9（Aug 8）の項に載っている | 本文で確認（両者で版番号が食い違う） | https://foodnoms.com/news/2026-summer-update 、App Store のバージョン履歴 |
| 体重の件数 | Foodnoms は1日1件の体重しか持たず、記録すると既存の値を置き換える（MCP のヘルプ記事の記述） | 本文で確認 | https://foodnoms.com/help/mcp |

### 読み込み

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 他アプリの栄養 | 他のアプリがヘルスケアに保存した栄養を取り込める。Foodnoms+ が必要。設定の Data & Integrations → Apple Health で「栄養データの読み込み」を有効にする。取り込んだエントリは Food Log に並んで表示され、Foodnoms からは削除できない | 本文で確認（前回の「Settings タブ > Apple Health > Read Nutrition Data」は 2023 年の FoodNoms 2 の記事の手順で、現行ヘルプでは Data & Integrations 配下） | https://foodnoms.com/help/reading-from-health 、https://foodnoms.com/news/foodnoms-2 |
| 取り込んだ栄養が目標に入るか | 現行ヘルプには記述なし。2023 年の FoodNoms 2 の記事に「他アプリで記録した品目が Foodnoms の食事ログに出て、目標に数えられる」とある | 本文で確認（2023 年の記事） | https://foodnoms.com/news/foodnoms-2 |
| 体重 | ヘルスケアへのアクセスが有効なら、体重計アプリなど他アプリの体重は自動で取り込まれる。同期を有効にした時点で過去の体重も表示される | 本文で確認 | https://foodnoms.com/help/track-weight 、https://foodnoms.com/news/2026-summer-update |
| 身長 | 体重と身長をヘルスケアと同期する | 本文で確認 | App Store の説明、https://foodnoms.com/news/2026-summer-update |
| 活動エネルギー | 自動カロリー目標は Apple Health の Active Energy Burned で調整できる。Body Profile → Active Energy → Use Apple Health | 本文で確認 | https://foodnoms.com/help/goals-and-workouts |
| 安静時エネルギー | 現行ヘルプは「Resting Energy も同じようにできる」とだけ書き、Foodnoms+ が必要とは書いていない。「Advanced Resting Energy Calculations」は Foodnoms+ の機能一覧にある。2023 年の FoodNoms 2 の記事は「ヘルスケアの安静時エネルギーを使うには FoodNoms Plus が必要」と書いていた | 本文で確認（前回の「Foodnoms+ が必要」は 2023 年時点の記述。現在の条件は明確な記述なし） | https://foodnoms.com/help/goals-and-workouts 、https://foodnoms.com/plus 、https://foodnoms.com/news/foodnoms-2 |
| ヘルスケアからの取り込みの料金 | 「Apple Health import, including burned calories」は Foodnoms+ | 本文で確認 | https://foodnoms.com/help/free-vs-plus |

### 参考: ヘルスケア以外の書き出しと、消費量の推定

- 設定の Data Export で**食事ログ全体**を CSV に書き出せる。目標は含まない（本文で確認、https://foodnoms.com/help/sharing-reports ）。前回書いた「期間は直近7日・30日・今月・先月」は本文に記述が無く、削除した。App Store の説明には「食事ログの CSV 書き出し、またはアカウント全体の書き出しの依頼がいつでもできる」とある。
- **Calibrated Energy**（Foodnoms+）: 直近 28 日の食事ログと体重から、1日の総消費量（TDEE）を推定する。1日の平均摂取量から体重傾向のエネルギー換算（1kg ≈ 7,700kcal）を引く。部分的にしか記録していない日は自動で除外する。体重は外れ値を除き、7 日で平滑化して傾向線を当てはめる。35 日・42 日でも計算して突き合わせる。800kcal 未満や 6,000kcal 超は提示しない。1回の調整は最大 400kcal。初回は直近 28 日のうち 14 日以上の記録と、1週間以上にわたる体重の記録が必要（本文で確認、https://foodnoms.com/help/calibrated-energy ）。Calibrated Energy を使っている間は、ヘルスケアの活動データを使わない（本文で確認、https://foodnoms.com/help/goals-and-workouts ）。
- MCP サーバー: Foodnoms Cloud に同期している食事ログと体重を、Claude など AI アプリから読み書きできる。Foodnoms+ が必要（本文で確認、https://foodnoms.com/help/mcp ）。ヘルスケアとは別の経路。

## 問い2: MacroFactor はヘルスケアに何を書き込み、何を読み込むか

公式ヘルプ「Integrations」の対応表（画像）: Apple Health について **Read Nutrition / Write Nutrition / Read Weight / Write Weight / Read Steps がすべて Yes**。表にあるのはこの5項目だけ（本文で確認、https://help.macrofactorapp.com/en/articles/102-integrations ）。

### 書き込み

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 栄養 | カロリー・マクロ・対応する微量栄養素をヘルスケア（と当時の Google Fit）に書き出せる（2022 年 3 月の v1.2.9 で追加） | 本文で確認 | https://macrofactor.com/version-1-2-9/ 、https://macrofactor.com/mm-march-2022/ 、https://help.macrofactorapp.com/en/articles/102-integrations |
| 栄養の単位（食品ごとか日の合計か） | 2022 年の公式ブログに「カロリー・マクロ・対応する微量栄養素を、その日の時間軸（timeline）の中で見られる」とある。食事の時刻付きで書くと読めるが、食品ごとか食事ごとかは書かれていない | 本文を探したが明確な記述なし（読み取りのみ） | https://macrofactor.com/mm-march-2022/ |
| 体重 | MacroFactor で記録した体重をヘルスケアに書き出せる | 本文で確認 | https://macrofactor.com/version-2-9-3/ 、https://macrofactor.com/mm-august-2024/ 、Integrations の対応表 |
| 体脂肪率 | 現行の対応表に体脂肪の書き込みは無い | 本文を探したが記述なし（対応表に無い） | Integrations の対応表 |
| 過去分の書き出し | 本文を探したが記述なし | 記述なし | — |

### 読み込み

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 体重 | ヘルスケアから体重を取り込む。体組成計のデータを取り込める | 本文で確認 | Integrations の対応表、https://help.macrofactorapp.com/en/articles/65-connect-health-connect-or-apple-health |
| 体脂肪率 | 2022 年の v1.2.9 のリリースノートに「Apple Health と Google Fit の連携が、体重と体脂肪の体組成計データを MacroFactor に渡すようになった」とある。ただし現行ヘルプの対応表に体脂肪は無い。現在も取り込むかは不明 | 2022 年時点は本文で確認、現在は記述なし | https://macrofactor.com/version-1-2-9/ 、Integrations の対応表 |
| **他アプリの栄養** | 2024 年 8 月の v2.9.3 から、ヘルスケアの「その日の」カロリー・マクロ・微量栄養素を取り込める。BYOFL のユーザーは、端末のヘルスケアで栄養を管理しながら MacroFactor のコーチングを使える、と説明 | 本文で確認 | https://macrofactor.com/version-2-9-3/ 、https://macrofactor.com/mm-august-2024/ |
| 取り込みの粒度 | 日ごとのカロリーとマクロの合計を取り込み、食品や食事は取り込まない。Food Log の時間軸ではなく Nutrition ページに出る | 本文で確認 | https://help.macrofactorapp.com/en/articles/36-where-is-my-nutrition-synced |
| **取り込んだ栄養が消費量の推定に入るか** | 消費量の記事に「"Calories in" は、MacroFactor で食事を記録しているか、同期している別の出どころから栄養を取り込んでいるかのどちらかなので、計算は簡単」とある。取り込んだ栄養は消費量の計算に使われる | 本文で確認 | https://help.macrofactorapp.com/en/articles/20-expenditure |
| 優先順位 | 栄養は「手入力 > Food Log > Apple Health / Health Connect > Fitbit」、体重は「手入力 > Apple Health / Health Connect > Fitbit」、歩数は「手入力 > Apple Health / Health Connect」。全ユーザー共通で変更できない | 本文で確認 | https://help.macrofactorapp.com/en/articles/56-weight-or-nutrition-source-priority 、https://help.macrofactorapp.com/en/articles/102-integrations |
| 優先順位の単位 | **日単位**。「その日に MacroFactor の手入力か Food Log の記録があると、常にそちらが優先され、その日の同期は行われない」。例として「MacroFactor の Food Log に 2000kcal、別アプリに 400kcal を記録した日は、2000kcal がその日の摂取量になる」 | 本文で確認 | https://help.macrofactorapp.com/en/articles/102-integrations 、https://help.macrofactorapp.com/en/articles/56-weight-or-nutrition-source-priority |
| 過去分 | 連携をつなぐと 30 日前までの記録を取り込み、以降はその日から同期を続ける | 本文で確認 | https://help.macrofactorapp.com/en/articles/65-connect-health-connect-or-apple-health |
| 手動での再同期 | v1.5.0 以降、ダッシュボードを下に引いて同期をやり直せる。その日に手入力や上位の記録があると同期されない。記録してから 5〜10 分待つよう案内している | 本文で確認 | https://help.macrofactorapp.com/en/articles/69-force-data-syncing |
| 歩数 | ヘルスケアから歩数を取り込める。ダッシュボードの General に Steps として出る | 本文で確認（前回の出典 v2.9.3 のリリースノートには歩数の記述が無く、出典を差し替えた） | Integrations の対応表、https://help.macrofactorapp.com/en/articles/255-how-to-import-your-step-count |
| ウェアラブルの消費エネルギー | 使わない。消費量は体重と栄養だけから計算する | 本文で確認 | https://help.macrofactorapp.com/en/articles/33-does-macrofactor-use-energy-expenditure-data-from-my-wearable-activity-tracker |
| 栄養の書き出しと取り込みを両方有効にしたとき、自分が書いた分を除外するか | 本文を探したが記述なし | 記述なし | — |

### 消費量の推定に関わる、その他の公式の記述

- 過去の日に記録を足すと消費量はすぐ再計算される。3 週間以内の過去の記録は現在の消費量に影響しうるが、3 週間より前はほぼ影響しない（本文で確認、https://help.macrofactorapp.com/en/articles/207-will-logging-food-to-a-previous-day-affect-my-expenditure-and-coaching-recommendations ）。
- 最大の弱点は「部分的な記録」（1食だけ記録漏れなど）。週ごとのチェックインで部分記録らしい日を確認し、除外できる（本文で確認、https://help.macrofactorapp.com/en/articles/29-how-do-macrofactor-s-coaching-algorithms-deal-with-partially-logged-days ）。
- 消費量の計算開始日を変えられる。初期消費量を手入力もできる（本文で確認、https://help.macrofactorapp.com/en/articles/61-change-your-expenditure-start-date 、https://help.macrofactorapp.com/en/articles/70-set-a-manual-initial-expenditure-estimate ）。

## 問い3: MacroFactor が他アプリから栄養を取り込む、ヘルスケア以外の手段

- 公式の連携は Apple Health（iOS）と Google Health Connect（Android）の2つ。Fitbit 連携は、栄養を取り込むための「一時しのぎ」として使っていたもので、2024 年 8 月に非推奨になった。現行ヘルプには「Fitbit 連携のサポートは非推奨となり、削除された」とある（本文で確認、https://macrofactor.com/version-2-9-3/ 、https://help.macrofactorapp.com/en/articles/102-integrations ）。
- ファイル（CSV など）で他アプリの食事記録を取り込む機能: ヘルプ全記事の一覧（sitemap、387 記事）を見た。取り込みに関する記事は、レシピの取り込み（リンク、AI）、歩数、ワークアウト・プログラムの取り込みだけで、他アプリの食事記録を取り込む記事は無かった（本文を探したが記述なし）。
- 逆方向（MacroFactor からの書き出し）はある。More > Data Management > Data Export。Quick Export は消費量・体重傾向・体重・カロリー・マクロ・主な目標を、期間を選んで表にする。Granular Export はデータの種類ごとに表を出す（本文で確認、https://help.macrofactorapp.com/en/articles/68-export-your-data ）。

## 問いに関わる HealthKit の仕様（本文で確認）

- **読み取り許可は見えない**: 読み取りを許可されていないと、その種類のデータは「存在しないかのように」見える。アプリは許可の有無を判別できない。書き込みだけ許可されている場合、自分が書いたデータだけが見える。
  https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:) 、https://developer.apple.com/documentation/healthkit/protecting-user-privacy
- **期間を限った読み取り許可（iOS 27 以降）**: ユーザーは許可画面で読み取り期間を限れる。`getEarliestAuthorizedSampleDate(for:completion:)` でその境界がわかる。Apple は、境界より前を「データが無い」ではなく「不明」として扱い、傾向やベースラインの計算を部分的なデータで動くようにするよう求めている。
  https://developer.apple.com/documentation/healthkit/hkhealthstore/getearliestauthorizedsampledate(for:completion:)
- **出どころ**: 各サンプルの `sourceRevision` で、どのアプリ（どのバージョン）が書いたかがわかる。
  https://developer.apple.com/documentation/healthkit/hkobject/sourcerevision
- **出どころごとの集計**: 統計クエリには出どころごとに分けて集計する `separateBySource` がある。`HKStatisticsCollectionQuery` で日ごとの合計を作れる。統計クエリは quantity サンプルにしか使えず、correlation（food）には使えない。
  https://developer.apple.com/documentation/healthkit/hkstatisticsoptions/separatebysource 、https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery 、https://developer.apple.com/documentation/healthkit/hkstatisticsquery
- **food correlation**: 複数の栄養サンプルを1つの「食品」にまとめる型。少なくとも dietaryEnergyConsumed を含めるべきとされ、食品名は `HKMetadataKeyFoodType` に入れる。correlation 型そのものには許可を求めず、中に入れる各サンプルの型ごとに許可を求める。保存には中身すべての型の書き込み許可が要る。読み取り時は、許可された型のサンプルだけが中身として見える。
  https://developer.apple.com/documentation/healthkit/hkcorrelation 、https://developer.apple.com/documentation/healthkit/hkcorrelationquery 、https://developer.apple.com/documentation/healthkit/hkcorrelationtypeidentifier/food
- correlation の中の quantity サンプルが、通常の quantity 型のクエリ（統計クエリを含む）でも返るかは、読んだページには書かれていなかった。
- **データの種類**: 摂取エネルギー（dietaryEnergyConsumed）は累積型、体重（bodyMass）は離散型。
  https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/dietaryenergyconsumed 、https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/bodymass

## S2-2・S5-5 への示唆

### S2-2（過去の体重・食事量から、使い始めた日から消費量を推定）

1. **前提が成り立つのは、ユーザーが各アプリの書き込みを有効にしていた期間だけ。** FoodNoms も MacroFactor も書き込みは設定で有効にする。FoodNoms には再書き出しの機能があるが、どこまでさかのぼるかはわからない。シナリオは「ヘルスケアに十分な過去の食事量がある」とは限らない前提で書くほうがよい。例: 食事量が足りなければ体重と式で初期値を置き、記録がたまるにつれて推定を更新する。
2. **FoodNoms の無料ユーザーはカロリーとマクロしか書き込んでいない**と考えられる。消費量の推定に要るのはカロリーなので S2-2 には支障ないが、過去のビタミン・ミネラルを読み込めるとは期待しない。
3. **二重計上を避ける設計が要る。** FoodNoms と MacroFactor の両方が書き込みを有効にして、同じ日に両方で記録していると、ヘルスケアの摂取エネルギーは足し合わされる。nu-tori は `separateBySource` で出どころごとに日の合計を取り、1日ごとに1つの出どころを選ぶ必要がある。MacroFactor 自身も日単位で1つの出どころを選ぶ方式をとっており、参考になる。
4. **部分的な記録の日を除く処理が要る。** Foodnoms（Calibrated Energy）も MacroFactor も、部分的にしか記録していない日が推定を大きく狂わせると公式に書き、除外する仕組みを持つ。過去データから推定するなら nu-tori にも同じ扱いが必要。
5. **体重は比較的確実。** 両アプリとも体重を書き込み、体重計アプリも書き込む。同じ計測が複数の出どころから重複して入るかは未確認（Foodnoms は内部では1日1件に保つが、ヘルスケア上の重複については記述なし）。
6. **期間を限った許可（iOS 27）への対応。** ユーザーが読み取り期間を短く限ると、過去分は読めない。境界より前は「不明」として扱い、推定の信頼度に反映する。
7. **読み取り許可が無いことは判別できない。** 「過去の食事データが0件」は「許可されていない」のかもしれない。UI の文言でどちらかに断定しない。
8. 参考: Foodnoms は 2026 年夏に Calibrated Energy（摂取量と体重から消費量を逆算）を入れた。MacroFactor の消費量推定と同じ考え方で、nu-tori の差別化の論点として CONTEXT.md や ADR で扱う価値がある。

### S5-5（nu-tori → ヘルスケア → MacroFactor）

1. **仕組みとして成り立つ。** MacroFactor はヘルスケアの日ごとのカロリー・マクロ・微量栄養素を取り込み、それを消費量の推定とコーチングに使う（本文で確認）。nu-tori は dietaryEnergyConsumed と各栄養の quantity サンプルを書けばよい。
2. **MacroFactor は日の合計しか見ない**ので、nu-tori が食事単位で書いても、MacroFactor 側の見え方は変わらないと考えられる。food correlation を使った場合に MacroFactor が中の quantity サンプルを数えるかは未確認なので、確実にするなら quantity サンプルとして書く（correlation を使うかは別に決める）。
3. **MacroFactor 側の設定が要る。** ユーザーは MacroFactor の More > Integrations で Apple Health を有効にし、栄養の読み取りを許可する必要がある。シナリオの「これまでどおり」はこの設定を前提にする。
4. **移行中に同じ日を MacroFactor でも記録すると、nu-tori の値はその日まるごと使われない。** 優先順位は日単位で、変更できない（本文で確認）。MacroFactor に1食でも記録した日は、MacroFactor の記録だけがその日の摂取量になる。シナリオは「移行中は食事の記録を nu-tori に一本化し、MacroFactor は進捗を見るだけにする」と書くのが正確。
5. **ループの心配。** ユーザーが MacroFactor の栄養の書き出しを有効にしたままでも、上の 4 で食事の記録を nu-tori に一本化すれば、MacroFactor が書き出す栄養は無い。ただし nu-tori が他アプリの栄養を読む機能を持つ場合は、nu-tori 自身が書いた分と他アプリの分を `sourceRevision` で分けること。
6. **取り込みは連携をつないだ時点から 30 日前まで。** nu-tori を使い始めてから 30 日以上たって MacroFactor の連携をつなぐと、それより前の分は MacroFactor に入らない。MacroFactor の消費量推定は 3 週間より前の記録の影響をほとんど受けないので、実用上の影響は小さいと考えられる（本文からの読み取り）。
7. **反映に時間差がある。** MacroFactor は記録から 5〜10 分待ってから手動で再同期するよう案内している。夜に nu-tori で直した値がすぐ MacroFactor に出るとは限らない。
8. 実機での最終確認（任意）: nu-tori（または任意のアプリ）で数日分を書き込み、MacroFactor の Nutrition ページと消費量に反映されるかを見る。

## 未確認の点（まとめ）

本文を探したが記述が無かったもの:
- FoodNoms が HKCorrelation（food）を使うか
- FoodNoms がエントリごとに書き込むか、日の合計を書き込むか（エントリごとと読める記述はあるが明言はない）
- FoodNoms の「Apple Health への再書き出し」の対象期間（書き込みを有効にする前の全履歴を含むか）
- MacroFactor が書き込みを有効にする前の過去分をヘルスケアに書き出すか
- MacroFactor の栄養の書き出しが食品単位か、食事単位か、日の合計か
- MacroFactor が現在も体脂肪率をヘルスケアから読むか（2022 年には読んでいた。現行の対応表には無い）。書き込みは対応表に無い
- MacroFactor が栄養の書き出しと取り込みを両方有効にしたとき、自分が書いた分を除外するか
- MacroFactor が food correlation の中の quantity サンプルを取り込むか。HealthKit のドキュメントにも、correlation の中のサンプルが通常の quantity クエリで返るかの記述は見つからなかった
- 同じ体重の計測が複数アプリから重複してヘルスケアに入るか

実機で確かめる必要があるもの:
- 上の correlation の扱いと、S5-5 の一連の流れ（nu-tori → ヘルスケア → MacroFactor の Nutrition ページと消費量）
