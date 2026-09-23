# FoodNoms・MacroFactor とヘルスケア（HealthKit）のデータのやりとり

調査日: 2026-09-23
対象: `docs/ui-design/0001-first-release/00-behavioral-scenarios.md` の S2-2・S5-5 の【要調査】

> **確認の方法と限界**
> 調査環境のネットワーク制限で、foodnoms.com・help.macrofactorapp.com・macrofactor.com・apps.apple.com の本文を直接取得できなかった。
> そのため FoodNoms と MacroFactor についての記述は、**公式ページ（ヘルプ・公式ブログ・App Store）を検索したときの検索エンジンの抜粋**に基づく。出典 URL は公式ページだが、本文全体は読めていない。確度は「抜粋で確認」と表記する。
> Apple の HealthKit ドキュメントは developer.apple.com から本文を直接取得して確認した（「本文で確認」）。
> 二次情報（レビュー記事など）は使っていない。確認できなかった点は「未確認」とした。

## 結論の要約

- **S2-2（過去の体重・食事量から初期消費量を推定）は、条件付きで成り立つ。**
  - 体重: FoodNoms（2026.8 以降）も MacroFactor も体重をヘルスケアに書き込む（抜粋で確認）。nu-tori は bodyMass を読めば過去の体重を得られる。
  - 食事量: FoodNoms は食事エントリの栄養をヘルスケアに書き込む（抜粋で確認）。MacroFactor もカロリー・マクロ・対応する微量栄養素を書き込む（抜粋で確認）。ただし両アプリとも「書き込み」は設定で有効にする必要があり、**ユーザーが有効にしていなかった期間の分は存在しない**。有効化前の過去分をさかのぼって書き出すかは未確認。
  - 両方のアプリが同じ食事を書き込んでいると、合計が二重になる。nu-tori は出どころ（sourceRevision）ごとに分けて集計し、1日ごとに1つの出どころを選ぶ必要がある。
  - iOS 27 から、ユーザーは読み取りを「期間を限って」許可できる。nu-tori はその境界より前を「データなし」ではなく「不明」として扱う必要がある（本文で確認）。
- **S5-5（nu-tori → ヘルスケア → MacroFactor）は成り立つ見込みが高い。**
  - MacroFactor は 2024年8月から、ヘルスケアの「その日の」カロリー・マクロ・微量栄養素を取り込める。公式ブログは、別の記録アプリを使いながら MacroFactor のコーチングを受ける使い方（BYOFL）を想定と書いている（抜粋で確認）。
  - 取り込むのは**日ごとの合計**で、食品や食事の単位では取り込まない。取り込んだ値は Food Log ではなく Nutrition ページに出る（抜粋で確認）。
  - 優先順位は「手入力 > MacroFactor の Food Log > ヘルスケア」。移行中に同じ日を MacroFactor でも記録すると、その日は MacroFactor の記録が優先され、nu-tori の値は使われない（抜粋で確認。「日単位で切り替わるか」は未確認）。
  - 取り込んだ栄養が消費量の推定に使われることを直接書いた一文は見つからなかった。ただし「BYOFL で MacroFactor のコーチングを使える」と公式ブログに書かれ、消費量は体重傾向と摂取カロリーから計算される（公式ヘルプ）ことから、使われると読める（**直接の記述は未確認**）。
  - 過去分の取り込みは、連携をつないだ時点から**30日前まで**（抜粋で確認）。

## 問い1: FoodNoms はヘルスケアに何を書き込み、何を読み込むか

### 書き込み

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 書き込みの有無 | 設定の Data & Integrations → Apple Health で「栄養データの書き込み」を有効にすると書き込む | 抜粋で確認 | https://foodnoms.com/help/writing-to-health |
| 書き込む栄養 | 「食事エントリが持っている栄養だけ」を書き込む。値が無い栄養は書き込まない | 抜粋で確認 | https://foodnoms.com/help/writing-to-health |
| 栄養の範囲 | App Store の説明では、ヘルスケアとの読み書きの対象はカロリー、マクロ、ビタミン、ミネラル、水分、カフェインなど | 抜粋で確認 | https://apps.apple.com/us/app/nutrition-tracker-foodnoms/id1479461686 |
| 食事単位か合計か | 変更履歴に「時刻の指定が無い "Other" の食事タイプのエントリを Apple Health に保存すると深夜0時になる問題を修正」とある。**エントリごとに時刻付きで書き込んでいる**と読める（日の合計ではない） | 抜粋からの読み取り | https://foodnoms.com/changelog/ |
| HKCorrelation（food）を使うか | 未確認 | 未確認 | — |
| 過去分の書き出し（有効化前の分をさかのぼって書くか） | 未確認 | 未確認 | — |
| Mac で記録した分 | Mac は直接ヘルスケアにアクセスできず、iPhone に同期された時点でヘルスケアに保存される | 抜粋で確認 | https://foodnoms.com/help/writing-to-health |
| 体重 | 2026.8（2026年夏）で体重記録を追加。体重はヘルスケアと**双方向**で同期する | 抜粋で確認 | https://foodnoms.com/news/2026-summer-update 、https://foodnoms.com/press/2026-8-release |

### 読み込み

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 他アプリの栄養 | 設定の Apple Health で「Read Nutrition Data」を有効にすると読み込む。Foodnoms+（有料）が必要。読み込んだ値は食事ログに出て目標の計算に入る | 抜粋で確認 | https://foodnoms.com/help/reading-from-health |
| 体重 | 双方向同期。スマート体重計や他アプリの体重は、同期を有効にした時点から表示される | 抜粋で確認 | https://foodnoms.com/news/2026-summer-update |
| 活動エネルギー・安静時エネルギー | 自動カロリー目標は Active Energy Burned で調整できる。安静時エネルギーをヘルスケアから使うのは Foodnoms+ が必要 | 抜粋で確認 | https://foodnoms.com/help/goals-and-workouts |

### 参考: ヘルスケア以外の書き出し
- 設定 > Data & Storage > Data Export で食事ログを CSV に書き出せる。期間は直近7日・30日・今月・先月。目標は含まない（抜粋で確認、https://foodnoms.com/help/sharing-reports ）。
- 2026.8 の「Calibrated Energy」は、記録した摂取量と体重の傾向から消費量を逆算して目標を提案する（抜粋で確認、https://foodnoms.com/news/2026-summer-update ）。nu-tori の消費量推定と似た機能が FoodNoms 側にも入った。

## 問い2: MacroFactor はヘルスケアに何を書き込み、何を読み込むか

### 書き込み

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 栄養 | 2022年3月から、カロリー・マクロ・対応する微量栄養素を Apple Health（と Google Fit）に書き出せる | 抜粋で確認 | https://macrofactor.com/mm-march-2022/ |
| 栄養の単位（食品ごとか日の合計か） | 未確認 | 未確認 | — |
| 体重 | MacroFactor で記録した体重をヘルスケアに書き出せる | 抜粋で確認 | https://macrofactor.com/mm-august-2024/ 、https://macrofactor.com/version-2-9-3/ |
| 体脂肪率 | 書き込むかは未確認 | 未確認 | — |

### 読み込み

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 体重・体脂肪率 | Apple Health 連携から体重と体脂肪（体組成計のデータ）を取り込む | 抜粋で確認 | https://help.macrofactorapp.com/en/articles/65-connect-health-connect-or-apple-health |
| **他アプリの栄養** | 2024年8月から、ヘルスケアの「その日の」カロリー・マクロ・微量栄養素を取り込める。別の記録アプリ（BYOFL）で記録しながら MacroFactor のコーチングを使えるようにするため、と説明 | 抜粋で確認 | https://macrofactor.com/mm-august-2024/ 、https://help.macrofactorapp.com/en/articles/102-integrations |
| 取り込みの粒度 | 日ごとのカロリー・マクロの合計だけを取り込み、食品や食事は取り込まない。Food Log ではなく Nutrition ページに出る | 抜粋で確認 | https://help.macrofactorapp.com/en/articles/36-where-is-my-nutrition-synced |
| 優先順位 | 手入力 > Food Log > Apple Health / Health Connect の順で、上位の出どころが優先される | 抜粋で確認 | https://help.macrofactorapp.com/en/articles/36-where-is-my-nutrition-synced |
| データの種類ごとの選択 | データの種類ごとに連携先を選べる | 抜粋で確認 | https://help.macrofactorapp.com/en/articles/102-integrations |
| 過去分 | つないだ時点から30日前までを取り込み、以降は継続して同期する | 抜粋で確認 | https://help.macrofactorapp.com/en/articles/102-integrations 、https://help.macrofactorapp.com/en/articles/65-connect-health-connect-or-apple-health |
| 歩数 | ヘルスケアと歩数を同期でき、ダッシュボードに出る | 抜粋で確認 | https://macrofactor.com/version-2-9-3/ |
| 取り込んだ栄養が消費量の推定に入るか | 消費量は体重傾向と摂取カロリーから計算される（公式ヘルプ）。BYOFL でコーチングを使えるとある（公式ブログ）。「取り込んだ値が推定に入る」と直接書いた一文は見つからなかった | 直接の記述は未確認 | https://help.macrofactorapp.com/en/articles/26-how-should-i-interpret-changes-to-my-energy-expenditure 、https://macrofactor.com/mm-august-2024/ |
| 栄養の書き出しと取り込みを同時に有効にしたとき、自分が書いた分を除外するか | 未確認 | 未確認 | — |

## 問い3: MacroFactor が他アプリから栄養を取り込む、ヘルスケア以外の手段

- 公式の連携は Apple Health（iOS）と Google Health Connect（Android）の2つ。以前は Fitbit 連携を栄養取り込みの「つなぎ」として使っていたが、ヘルスケアからの取り込みに対応したので Fitbit 連携は廃止した（抜粋で確認、https://macrofactor.com/mm-august-2024/ 、https://help.macrofactorapp.com/en/articles/102-integrations ）。
- ファイル（CSV など）で他アプリの食事記録を取り込む機能は、公式ヘルプの検索では見つからなかった（**未確認**。見つからなかったことは「無い」ことの証明ではない）。
- 逆方向（MacroFactor からの書き出し）はある。More > Data Management > Data Export で、Quick Export（消費量、体重傾向、体重、カロリー、マクロ、目標）と Granular Export（データの種類ごとの表）を書き出せる（抜粋で確認、https://help.macrofactorapp.com/en/articles/68-export-your-data ）。

## 問いに関わる HealthKit の仕様（本文で確認）

- **読み取り許可は見えない**: 読み取りを許可されていないと、その種類のデータは「存在しないかのように」見える。アプリは許可の有無を判別できない。書き込みだけ許可されている場合、自分が書いたデータだけが見える。
  https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:) 、https://developer.apple.com/documentation/healthkit/protecting-user-privacy
- **期間を限った読み取り許可（iOS 27 以降）**: ユーザーは許可画面で読み取り期間を限れる。`getEarliestAuthorizedSampleDate(for:completion:)` でその境界がわかり、境界より前は「データが無い」ではなく「不明」として扱うよう Apple は求めている。傾向やベースラインの計算は部分的なデータで動くようにせよ、とある。
  https://developer.apple.com/documentation/healthkit/hkhealthstore/getearliestauthorizedsampledate(for:completion:)
- **出どころ**: 各サンプルの `sourceRevision` で、どのアプリ（どのバージョン）が書いたかがわかる。
  https://developer.apple.com/documentation/healthkit/hkobject/sourcerevision
- **出どころごとの集計**: 統計クエリには出どころごとに分けて集計する `separateBySource` がある。`HKStatisticsCollectionQuery` で日ごとの合計を作れる。統計クエリは quantity サンプルにしか使えず、correlation（food）には使えない。
  https://developer.apple.com/documentation/healthkit/hkstatisticsoptions/separatebysource 、https://developer.apple.com/documentation/healthkit/hkstatisticscollectionquery 、https://developer.apple.com/documentation/healthkit/hkstatisticsquery
- **food correlation**: 任意の数の栄養サンプルを1つの「食品」にまとめる型。食品名は `HKMetadataKeyFoodType` に入れる。
  https://developer.apple.com/documentation/healthkit/hkcorrelationtypeidentifier/food 、https://developer.apple.com/documentation/healthkit/hkmetadatakeyfoodtype
- **データの種類**: 摂取エネルギー（dietaryEnergyConsumed）は累積型、体重（bodyMass）は離散型。
  https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/dietaryenergyconsumed 、https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/bodymass

## S2-2・S5-5 への示唆

### S2-2（過去の体重・食事量から、使い始めた日から消費量を推定）

1. **前提が成り立つのは「ユーザーが各アプリのヘルスケア書き込みを有効にしていた期間」だけ。** FoodNoms も MacroFactor も書き込みは設定で有効にする必要がある。有効化前の分をさかのぼって書くかは未確認。シナリオは「ヘルスケアに過去の食事量がある」とは限らない前提で書くほうがよい（例: 食事量が足りなければ体重だけで初期値を置き、記録がたまるにつれて推定を更新する）。
2. **二重計上を避ける設計が要る。** FoodNoms と MacroFactor の両方が書き込みを有効にしていて、同じ日に両方で記録していると、ヘルスケアの摂取エネルギーは足し合わされる。nu-tori は `separateBySource` で出どころごとに日の合計を取り、1日ごとに1つの出どころを選ぶ（例: MacroFactor の方式に倣い、優先順位を決める）必要がある。
3. **体重は比較的確実。** 両アプリが体重を書き込み、体重計アプリも書き込む。ただし同じ計測が複数の出どころから重複して入る可能性がある（重複の有無は未確認）。
4. **期間を限った許可（iOS 27）への対応。** ユーザーが読み取り期間を短く限ると、過去分は読めない。境界より前は「不明」として扱い、推定の信頼度に反映する。
5. **読み取り許可が無いことは判別できない。** 「過去の食事データが0件」は「許可されていない」かもしれない。UI の文言でこれを断定しない。
6. 参考: FoodNoms は 2026.8 で Calibrated Energy（摂取量と体重から消費量を逆算）を入れた。nu-tori の差別化の論点として CONTEXT.md や ADR で扱う価値がある。

### S5-5（nu-tori → ヘルスケア → MacroFactor）

1. **仕組みとしては成り立つ。** MacroFactor はヘルスケアの日ごとのカロリー・マクロ・微量栄養素を取り込む。nu-tori は dietaryEnergyConsumed と各栄養の quantity サンプルを書けばよい。MacroFactor は日の合計しか見ないので、nu-tori が食事単位で書いても（food correlation を使っても使わなくても）MacroFactor 側の見え方は同じと考えられる（correlation の中の quantity サンプルを MacroFactor が数えるかは未確認）。
2. **MacroFactor 側の設定が要る。** ユーザーが MacroFactor で Apple Health の栄養取り込みを有効にし、MacroFactor にヘルスケアの読み取りを許可する必要がある。シナリオの「これまでどおり」は、この設定変更を前提にする。
3. **同じ日を MacroFactor でも記録すると nu-tori の値は使われない。** 優先順位が「手入力 > Food Log > Apple Health」のため。移行中の「両方で記録する」使い方では、MacroFactor は MacroFactor の記録を使う。これは MacroFactor 側の仕様で、nu-tori からは変えられない。
4. **ループの心配。** ユーザーが MacroFactor の「栄養の書き出し」を有効にしたままだと、MacroFactor の記録もヘルスケアに入る。nu-tori が栄養を読む機能を持つ場合は、nu-tori 自身が書いた分と他アプリの分を sourceRevision で分けること。
5. **取り込んだ栄養が MacroFactor の消費量推定に入ることを、直接書いた一文は確認できていない**（BYOFL でコーチングを使える、という記述からは入ると読める）。最終確認は実機で行うのが確実: nu-tori（または任意のアプリ）で数日分を書き込み、MacroFactor の Nutrition ページと消費量の推移に反映されるかを見る。
6. 取り込みはつないだ時点から30日前までなので、nu-tori を使い始めてから30日以上たってから MacroFactor の連携をつなぐと、それより前は MacroFactor に入らない。

## 未確認の点（まとめ）

- FoodNoms が HKCorrelation（food）を使うか
- FoodNoms・MacroFactor が、書き込みを有効にする前の過去分をさかのぼってヘルスケアに書き出すか
- MacroFactor の栄養の書き出しが食品単位か日の合計か
- MacroFactor が体脂肪率をヘルスケアに書き込むか
- MacroFactor がヘルスケアから取り込んだ栄養を消費量推定に使うことの直接の記述（強く示唆はされている）
- MacroFactor の優先順位が日単位で切り替わるか、食事単位か
- MacroFactor が栄養の書き出しと取り込みを同時に有効にしたとき、自分が書いた分を除外するか
- MacroFactor が correlation 内の quantity サンプルを取り込み対象として数えるか
- MacroFactor に、ヘルスケア以外で他アプリの食事記録を取り込む手段（ファイル取り込みなど）があるか
- 上記の公式ページの本文全体（ネットワーク制限で検索の抜粋のみ確認）
