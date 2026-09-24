# 目標の設定をタイムラインのカード内で進めることと Apple の HIG

調査日: 2026-09-24
対象: `docs/ui-design/0001-first-release/` の ⑥ 目標の設定の流れ（`05-navigation.md` の「⑥ に渡すこと」、`03-frames/goal-setup.html`）

> **確認の方法と限界**
> - Apple Human Interface Guidelines（以下 HIG）の各ページは、HTML が JavaScript で組み立てられるため、同じ内容の JSON（`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.json`）を取得して**本文を直接読んだ**。出典にはふつうの HIG の URL を書く。
> - HealthKit の開発者向けドキュメント（developer.apple.com/documentation/healthkit 以下）も同じく JSON で本文を読んだ。App Store Review Guidelines は HTML を取得して読んだ。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。
> - 本文の記述から推し量ったものは「本文からの読み取り」と書き、何から読み取ったかを添える。
> - 本文や関連ページを探しても記述が無かったものは「本文を探したが記述なし」と書く。
> - 画像の中の説明（たとえばシートのボタン配置の図）は、JSON に入っている画像の説明文（abstract / alt）で読んだ。画像そのものは見ていない。
> - 実機での確認、プロトタイプでの確認はしていない。二次情報（ブログ、記事、SNS）は使っていない。
> - HIG は更新される。本文は 2026-09-24 時点のもの（例: Sheets は 2026-03-24 にボタン配置の指針を更新、Scroll views は 2026-06-08 に更新）。

## 結論の要約

- **判定: 条件付きで可。**
  - HIG には「タイムラインのカードをその場で広げ、中で手順を1ページずつ進める」形を名指しで扱うページは無い。認める記述も、禁じる記述も無い（本文を探したが記述なし）。
  - ただし、部品ごとの指針（Disclosure controls の「必要になるまで隠し、その場で広げる」、Scroll views の「縦のスクロールの中に横のスクロールを置くのはかまわない」、Collections の「明示的な操作に応じたレイアウト変更」）を組み合わせると、この形は指針に反しない（本文からの読み取り）。
  - シートで出す形も指針にそのまま合う。Sheets は「今の文脈に近い、範囲の狭い作業」に使うものとしており、目標の設定はこれに当たる（本文で確認＋読み取り）。どちらも可で、優劣を HIG が決めているわけではない。
  - カード内で進める形の強みは、**ヘルスケアの許可のシート（システムが出す）が自分のシートの上に重ならない**こと。HIG は「シートは一度に1つ」「別のシートを出すなら先に最初のシートを閉じる」と書いている（本文で確認）。シートで出すと、この指針との関係を詰める必要が出る（本文からの読み取り）。
  - カード内で進める形の弱みは、閉じる・戻るの**決まった置き場所が無い**こと。シートなら HIG がボタンの位置まで決めているが、カードでは自分で分かりやすく作る必要がある。

- **守ること（詳しくは「実装で守ること」）**
  1. カードに、いつでも見える「閉じる」を置く。閉じても入力を失わず、次に開いたら続きから始める。
  2. 1ページに1つの問い。戻る手段を置く。進むボタンは、必要な入力がそろうまで押せないようにする。
  3. 残りの手順の表示は、**操作できない表示**にする（「2/3」の文字、または押せない点）。HIG の Page control は「同格のページを自由に行き来する」部品で、タップやなぞりで先へ飛べてしまう。Progress indicator は「処理の待ち時間」を表す部品で、手順の数には使わない。
  4. 手順の数が途中で変わる（③が要らないこともある）ので、数は正確に出す。確定してから出すか、確定したら直す。
  5. カードの中に縦のスクロールを作らない（タイムラインの縦スクロールと重なる）。ページの切り替えは横でよい。
  6. 広げたときは、カードが画面に収まるように必要な分だけ自動でスクロールする。キーボードが入力欄を隠さないようにする。
  7. ヘルスケアの許可は、向きを選んだ直後（目標に体重・身長などが要る、と分かる時点）に、システムの許可画面で求める。許可画面をまねた自前の画面を作らない。説明を足すなら使用目的の文（NSHealthShareUsageDescription）とカードの中の短い一文で。
  8. 読み取りを拒否されたかどうかはアプリから分からない。**③の要否は「データが取れたか」だけで決める**。「許可されませんでした」とは言わない。許可が無くても手で入力して先へ進めるようにする。
  9. 求めるデータの種類は目標の計算に要るものだけにする。
  10. 案を選んだら確定する流れは可。ただし確定したことが分かるようにし（カードが目標の要約に変わる等）、あとで目標を切り替えられることを保つ。
  11. 視差効果を減らす設定（Reduce Motion）のときは、ページの横移動やカードの拡大をフェードに置き換える。VoiceOver で今の手順と残りの数が読まれるようにする。

## 問い1: HIG は画面の中での展開（その場で広げる）を認めているか

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| その場で広げる部品 | Disclosure controls は「関係する情報や機能を見せたり隠したりする」部品。「必要になるまで詳細を隠す」（"Use a disclosure control to hide details until they're relevant."）。押すと「ビューが広がったり縮んだりして中身を収める」（"the view expands or collapses accordingly to accommodate the content"） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/disclosure-controls |
| 広げる部品の置き場所 | 広げるボタンは「見せたり隠したりする中身の近くに置く」。1つのビューに広げるボタンは1つまで | 本文で確認 | 同上 |
| 目標の設定に当てはまるか | Disclosure controls の例は「詳細な設定」「フォルダの階層」などで、手順を進める流れの例は無い。カードのタップで広げることは、この部品の考え方（必要になったときに、その場に出す）に沿う。ただし SwiftUI の DisclosureGroup をそのまま使う形にはならない | 本文からの読み取り（例の範囲から） | 同上 |
| レイアウトが動くこと | Collections（iOS）: 「見ている・操作している間にレイアウトを変えるのは避ける。ただし明示的な操作に応じる場合は別」（"avoid changing the layout while people are viewing and interacting with it, unless it's in response to an explicit action"）。変化は「意味が通り、追いやすい」ように | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/collections |
| タップで広げることは明示的な操作か | カードのタップは明示的な操作なので、上の条件を満たす。逆に、ヘルスケアの結果が戻った瞬間などに勝手にカードの高さが大きく変わるのは、上の指針に照らして避けたい | 本文からの読み取り（Collections から） | 同上 |
| モーダルにするべき場面 | Modality: モーダルは「はっきりした利点があるときだけ」（"Present content modally only when there's a clear benefit."）。利点の例に「範囲の狭い別の作業を、元の文脈を見失わずに進める」（"perform a distinct, narrowly scoped task without losing track of their previous context"）がある | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/modality |
| 目標の設定はモーダルでなければならないか | Modality は「モーダルにしてよい場面」を書いているが、「こういう作業はモーダルにしなければならない」とは書いていない。モーダルにしない形（その場で進める）を禁じる記述も無い | 本文を探したが記述なし | 同上 |
| 画面内で手順を進める形そのもの | HIG の中で「リストやカードの中で、複数の手順を1ページずつ進める」形を扱う記述は、上記のページ（Modality、Sheets、Onboarding、Disclosure controls、Lists and tables、Collections、Scroll views、Page controls、Progress indicators、Entering data）を探したが無かった | 本文を探したが記述なし | 各ページ（出典一覧） |
| 1ページに1つの操作 | Accessibility の Assistive Access の項に「複数の手順の流れを分け、1画面で1つの操作に集中できるようにする」（"Break up multistep workflows so people can focus on a single interaction per screen."）。Assistive Access がオンのときの指針だが、1ページ1問の形を後押しする | 本文で確認（適用範囲は Assistive Access） | https://developer.apple.com/design/human-interface-guidelines/accessibility |

## 問い2: ページ送りと、残りの手順の表示

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 縦のスクロールの中の横のページ | Scroll views: 「同じ向きのスクロールを入れ子にしない」（"Avoid putting a scroll view inside another scroll view with the same orientation."）。「縦の中に横を置くのはかまわない」（"It's alright to place a horizontal scroll view inside a vertical scroll view"） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/scroll-views |
| カードに当てはめると | タイムラインは縦にスクロールする。カードの中でページを横に切り替えるのは可。カードの中にさらに縦スクロールを作るのは避ける。③（身体データを1ページで入力）が長くなっても、カードの高さを伸ばして収め、カードの中で縦スクロールさせない | 本文からの読み取り（Scroll views から） | 同上 |
| ページ単位のスクロール | 「内容に合うならページ単位のスクロールを検討する」。iOS では「ページ単位のときは Page control を出すことを検討する」。その場合、同じ軸のスクロールインジケータは出さない | 本文で確認 | 同上 |
| Page control とは何か | 「平らなリストの中のページを1つずつ表す点の列」（"each of which represents a page in a flat list"）。「順番のあるページの間の移動を表すのに使う」（"represent movement between an ordered list of pages"）。「階層や順不同の関係は表さない」 | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/page-controls |
| Page control の操作 | iOS では点のタップやなぞり（scrub）でページを移動できる。なぞると端まで一気に行ける | 本文で確認 | 同上 |
| 手順の表示に Page control を使ってよいか | 「順番のあるページ」という点では合うが、Page control は**同格のページを自由に行き来する**部品として書かれている（例は天気アプリの地点）。目標の設定は、前の答え（向き）が無いと先へ進めず、③は出ないこともある。操作できる Page control を置くと、答える前に先へ飛べてしまう。点で出すなら、押せない・なぞれない表示にする | 本文からの読み取り（Page controls の説明と操作から） | 同上 |
| Page control の位置と数 | 「ビューの下の中央に置く」。「10 を超える点は数えにくい」。点の色は変えない | 本文で確認 | 同上 |
| Progress indicator は使えるか | Progress indicators は「読み込みや長い処理の間、アプリが止まっていないと知らせる」部品。「処理が続く間だけ出て、終われば消える」（"appearing only while an operation is ongoing and disappearing after it completes"）。手順の数を示す用途は書かれていない | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/progress-indicators |
| 手順の数の表示の指針 | 複数の手順の流れで「あと何手順か」をどう見せるかを定めた記述は、Progress indicators、Page controls、Sheets、Modality、Onboarding を探したが無かった | 本文を探したが記述なし | 各ページ |
| 表示の正確さ | Progress indicators に「進み具合はできるだけ正確に」「90% まで5秒、残り 10% に5分では、欺かれたように感じさせる」とある。処理の待ち時間の話だが、手順の数も同じで、③が出るか出ないかで総数が変わるなら、実際と合う数を出すべき | 前半は本文で確認、後半は本文からの読み取り | 同上 |
| 待ちが出るとき | ヘルスケアの読み取りや案の計算で待ちが出るなら、そこでは Progress indicator（回る表示）を使う。説明を添えるなら「読み込み中」のようなあいまいな語を避け、具体的に書く | 本文で確認（指針）＋本文からの読み取り（当てはめ） | 同上 |
| 必須の入力と進むボタン | Entering data: 「次へ」「続ける」ボタンは、必要なデータが入るまで押せないようにする（"make the button available only after people enter the data you require"） | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/entering-data |

## 問い3: シートで出す場合との比較

### シートについて HIG が書いていること

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| シートの用途 | 「今の文脈に近い、範囲の狭い作業」（"a scoped task that's closely related to their current context"）。「情報を求める、または親ビューに戻る前に終えられる簡単な作業」に向く | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/sheets |
| 長い流れ | 「複雑な流れや長い流れには、シート以外を検討する」（"For complex or prolonged user flows, consider alternatives to sheets."）。例は全画面のモーダル | 本文で確認 | 同上 |
| 目標の設定の長さ | 最大4ページ（向き、許可、身体データ、案）で、1ページ1問。「複雑・長い」には当たらないと考えられる。シートで出してもこの指針には反しない | 本文からの読み取り | 同上 |
| 一度に1つ | 「メインの画面から出すシートは一度に1つ」。「シートの中の操作で別のシートが出るなら、先に最初のシートを閉じる」（"close the first sheet before displaying the new one"）。Modality にも「別のモーダルを出す前に、今のモーダルを閉じられるようにする」 | 本文で確認 | 同上、https://developer.apple.com/design/human-interface-guidelines/modality |
| ヘルスケアの許可との関係 | HealthKit の許可はシステムが「authorization sheet」（許可のシート）として出す。自前のシートの中で許可を求めると、シートの上にシートが重なる。HIG の「一度に1つ」がシステムの許可シートにも及ぶかは書かれていない。ただし重なりを避けたいなら、カード内で進める形のほうが素直に合う | 前半は本文で確認、後半は本文からの読み取り | https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data 、Sheets |
| 複数手順のシートのボタン | iOS の複数手順のシート: 最初の手順は左上に Cancel、右上に Done（未完了の間は押せない状態）。2つ目以降は Back が Cancel に置き換わる。最後の手順で Done が押せるようになる。Cancel・Done・Back の3つを同時に出さない | 本文で確認（図の説明文から） | Sheets |
| Done を置くなら | 「Done を置くなら、必ず Cancel か Back と組にする」 | 本文で確認 | 同上 |
| 目標の設定に当てはめると | 案を選ぶと確定するので、Done は要らない。Done を置かない場合の配置は本文に無い。2つ目以降で Back が Cancel に置き換わると、閉じるのは下へのスワイプだけになる | 前半は本文からの読み取り、後半は本文で確認した配置からの読み取り | 同上 |
| スワイプで閉じる | 「縦のスワイプで閉じられるようにする」。「保存していない変更があるなら、アクションシートで確かめる」 | 本文で確認 | 同上 |
| 途中で閉じたとき | 目標の設定は途中の入力を残して続きから始めるので、閉じても失うものは無い。この場合、確認は要らない。Feedback にも「データが失われるのが予想どおりの結果なら警告しない」「予想外で取り返せない損失のときに警告する」とある | 本文からの読み取り（Sheets、Modality、Feedback から） | 同上、https://developer.apple.com/design/human-interface-guidelines/feedback |
| 高さ（detent） | iPhone では medium（約半分）と large（全体）。「内容が全体の高さで役に立つなら medium を付けない」。例はメールやメッセージの作成画面 | 本文で確認 | Sheets |
| 高さの当てはめ | ③は入力が5項目あり、キーボードや選択部品が出る。medium だと窮屈になりやすい。シートで出すなら large のみが無難 | 本文からの読み取り | 同上 |
| 作業名を示す | Modality: 「モーダルの作業が何かを分かるようにする。作業を名づける題を付ける」 | 本文で確認 | Modality |
| 階層を持たせない | Modality: 「モーダルの中に階層を作ると戻り方を忘れる。中に複数のビューが要るなら、1本の道にする」 | 本文で確認 | 同上 |
| 途中から再開 | シートでもカードでも、途中から再開することについて Sheets と Modality には記述が無い。Launching に「再起動したら前の状態に戻し、続きからできるようにする」（"Restore the previous state when your app restarts so people can continue where they left off."）がある。アプリの再起動についての指針だが、途中で閉じた流れを続きから始めることと同じ考え | 本文で確認（Launching）＋本文からの読み取り（当てはめ） | https://developer.apple.com/design/human-interface-guidelines/launching |

### 比べると

| 観点 | カード内で進める | シートで出す | 根拠 |
|---|---|---|---|
| HIG での位置づけ | 名指しの指針は無い。部品ごとの指針から組み立てる | Sheets と Modality がそのまま当てはまる | 上の表 |
| 元の文脈 | タイムラインが見えたまま。文脈を見失わない | 親ビューは隠れるが、Modality の言う「文脈を見失わずに別の作業」の手段 | Modality |
| ヘルスケアの許可シート | タイムラインの上に1枚出るだけ | 自前のシートの上に重なる。「一度に1つ」との関係を詰める必要 | Sheets、HealthKit のドキュメント |
| 閉じる・戻る | 置き場所の決まりが無い。自分で分かりやすく作る | 左上 Cancel／Back、スワイプで閉じる、と決まっている | Sheets、Modality |
| 入力とキーボード | タイムラインのスクロールの中でキーボードが入力欄を隠さないよう、自動スクロールが要る | シートの中で完結しやすい | Scroll views（自動スクロールの指針） |
| レイアウトの動き | カードが広がりタイムラインの下が押し下がる。タップへの応答なら可 | 画面の上にシートが出るだけ | Collections |
| 他の入口との一貫性 | 「次の目標を選ぶ」（タイムライン）、「目標を切り替える」（目標の画面）からも同じ流れを開く（`05-navigation.md`）。目標の画面から開くときは、カードの形をそのまま使えないかもしれない | どの入口からでも同じ見え方にしやすい | 本文からの読み取り（nu-tori の設計資料から。HIG の記述ではない） |

## 問い4: ヘルスケアの許可の求め方

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| 求める時機 | 「ヘルスケアのデータへのアクセスは、要るときに求める」（"Request access to health data only when you need it."）。例: 体重を記録するときに体重のアクセスを求めるのはよいが、起動直後は避ける。「求める理由が今の文脈と明らかに関係していると、アプリの意図が伝わる」 | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/healthkit |
| 栄養アプリの例 | HIG の HealthKit ページの例に「栄養アプリが、カロリーの目標を決め食事の勧めをするために、体重と活動のデータを求める」がある | 本文で確認 | 同上 |
| 向きを選んだ直後という時機 | 目標を立てる流れの中で、目標の計算に体重・身長などが要る時点なので、「要るときに」「文脈と関係して」に合う | 本文からの読み取り | 同上 |
| 許可画面の説明 | 「システムの許可画面に説明の文を足す。なぜ要るか、共有すると何が良いかを短く書く」。「システムの許可画面の動きや中身をまねた自前の画面を足さない」（"Avoid adding custom screens that replicate the standard permission screen's behavior or content."） | 本文で確認 | 同上 |
| 説明の文の書き方 | Privacy: 使用目的の文は「短く、完結した、具体的な文」。受け身を避け、文末に句点。「より良い体験のために必要です」のようなあいまいな理由は悪い例 | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/privacy |
| 読み取りと書き込みで別の文 | 読み取りは NSHealthShareUsageDescription、書き込みは NSHealthUpdateUsageDescription。設定しないと許可を求めたときにアプリが落ちる | 本文で確認 | https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:) |
| 許可の前の説明画面 | Privacy の「Pre-alert screens」: 説明の画面を出すなら、ボタンは1つで「続ける」「次へ」のように許可のアラートを開くと分かる語にする。「許可」という語は使わない。アラートを見ずに画面を離れる手段（閉じる、キャンセル）を置かない。この指針の対象として挙がっているのはカメラ、マイク、位置、連絡先、カレンダー、トラッキングで、ヘルスケアは名指しされていない | 本文で確認 | Privacy |
| カードでの当てはめ | 許可の前に説明のページを1枚挟むと、カードの「閉じる」と Pre-alert の「離れる手段を置かない」がぶつかる。また HealthKit ページは「許可画面をまねた自前の画面」を避けるよう求めている。説明のページは作らず、向きのページに「次にヘルスケアのデータの読み取りを求めます」程度の一文を置き、向きを選んだらそのままシステムの許可画面を出すのが、両方の指針に合う | 本文からの読み取り（Privacy と HealthKit ページから） | Privacy、HealthKit |
| 求める種類 | Privacy: 「本当に要るデータだけを求める」「求めはできるだけ具体的に」。App Store Review Guidelines 5.1.1(iii): 「中心の機能に関係するデータだけを求める」 | 本文で確認 | Privacy、https://developer.apple.com/app-store/review/guidelines/ |
| まとめて求めなくてよい | 「すべての種類を一度に求める必要はない。要るときまで待つほうが理にかなうこともある」 | 本文で確認 | https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data |
| 読み取りを拒否されたか分からない | 「読み取りを許可されたか拒否されたか、アプリには分からない」。拒否されると、そのアプリが保存したデータしか返らない（"your app doesn't know whether someone granted or denied permission to read data"）。authorizationStatus(for:) が示すのは書き込み（共有）の状態だけ | 本文で確認 | 同上、https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:) |
| 期間を限った許可 | 最近の一定期間だけの読み取りを許す選び方がある。全部の許可と拒否は区別できないが、期間を限った許可だけは getEarliestAuthorizedSampleDate(for:completion:) で分かる | 本文で確認 | https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data |
| 流れへの影響 | ③（足りない身体データの入力）を出すかどうかは、「許可されたか」ではなく「データが取れたか」で決めるしかない。拒否・許可したがデータが無い・期間外、のどれでも同じ見え方になるので、文言は「ヘルスケアに見つからなかった項目を入れてください」のように、拒否を前提にしない書き方にする | 本文からの読み取り（上の2項目から） | 同上 |
| 許可しない人への代わり | App Store Review Guidelines 5.1.1(iv): 「利用者の許可の設定を尊重し、要らないアクセスへの同意をだまして・強いて求めない」「同意しない人への代わりの手段を、できるなら用意する」（例: 位置の代わりに住所の手入力） | 本文で確認 | https://developer.apple.com/app-store/review/guidelines/ |
| ③はその代わりになる | ヘルスケアから取れない項目を手で入れられる③は、この「代わりの手段」に当たる。許可しなくても目標を立て終えられるようにする | 本文からの読み取り | 同上 |
| 何度求めてもよい | 「許可は変えられるので、要るたびに求める」。すでに全種類について選んでいれば、requestAuthorization は画面を出さずに完了を返す | 本文で確認 | HealthKit（HIG）、requestAuthorization のドキュメント |
| 再開のときの当てはめ | 途中で閉じて再開したとき、②をもう一度通しても、選び済みなら許可画面は出ない。再開のたびに呼んでも害は無い | 本文からの読み取り | 同上 |
| 使えない端末 | 他の HealthKit の関数より先に isHealthDataAvailable() で使えるか確かめる。使えないと他の関数はエラーになる | 本文で確認 | https://developer.apple.com/documentation/healthkit/setting-up-healthkit |
| 当てはめ | ヘルスケアが使えない場合は②を飛ばし、③で全部を入れる流れにする | 本文からの読み取り | 同上 |
| アプリ内で許可を切り替える画面 | 「ヘルスケアのデータの共有は、システムのプライバシー設定だけで管理する。アプリ内に、データの流れを変える画面を作らない」 | 本文で確認 | HealthKit（HIG） |
| 当てはめ（目標の設定の外） | `05-navigation.md` のアカウントには「許可の状態」がある。ここで許可を切り替えるスイッチを作らず、状態を見せる・設定アプリへ案内するにとどめる必要がある。また読み取りの許可の状態はアプリから分からないので、「許可されています」とは表示できない | 本文からの読み取り | 同上、authorizing-access-to-health-data |
| 呼び方 | 画面の文言では「HealthKit」と言わない。「Apple Health」「ヘルスケア」（端末の表示に合わせた訳）を使う | 本文で確認 | HealthKit（HIG）の Editorial guidelines |
| 用途 | HealthKit は健康・フィットネスの目的で使い、そのことを文言と画面で明らかにする。ヘルスケアのデータを広告に使わない | 本文で確認 | https://developer.apple.com/documentation/healthkit/protecting-user-privacy 、App Store Review Guidelines 2.5.1・5.1.3 |

## 問い5: オンボーディング・起動の考え方との整合

| 項目 | 所見 | 確度 | 出典 |
|---|---|---|---|
| オンボーディングの基本 | 「理想は、使ってみるだけで分かること。要るなら、速く、楽しく、飛ばせる流れにする」（"fast, fun, and optional"）。オンボーディングは起動の一部ではない | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/onboarding |
| 設定を後回しに | 「必須でない設定の流れは後回しにする。妥当な初期値を用意して、すぐに使い始められるようにする」（"Postpone nonessential setup flows or customization steps."） | 本文で確認 | 同上 |
| 文脈に沿った案内 | 「1本のオンボーディングより、文脈に合った小さな案内の集まりを検討する」。「画面の特定の場所についての案内は、その場所の近くに出す」 | 本文で確認 | 同上 |
| 許可をオンボーディングに入れるか | 「動くために個人のデータが要るなら、許可の求めをオンボーディングに入れることを検討する。そうでなければ、その機能を初めて使うときに求める」 | 本文で確認 | 同上 |
| 起動時に許可を求めない | Privacy: 「アプリが動くのに必須でない限り、起動時に許可を求めない」 | 本文で確認 | Privacy |
| カードの形との整合 | 起動時に目標の設定を強いる流れにせず、タイムラインの先頭のカードから始める形は、「後回しにする」「その場所の近くに出す」「機能を初めて使うときに許可を求める」に合う。1ページ1問・最大4ページの短い流れは「速く」にも合う | 本文からの読み取り | Onboarding、Privacy |
| 目標が無い間 | 目標を立てるまでタイムライン（体重の入力、食事の撮影）が使えるなら、「すぐに使い始められる」に合う。目標が無いと使えない部分がある場合は、その部分の見せ方を別に考える必要がある | 本文からの読み取り | Onboarding |
| 続きから | Launching: 「前の状態に戻し、続きからできるようにする」「元の場所に戻るのに手順をたどり直させない」 | 本文で確認 | https://developer.apple.com/design/human-interface-guidelines/launching |
| 入力を減らす | Entering data: 「システムから得られる情報は入力させない。許可を得て取れるものも含む」。「妥当な初期値を入れておく」。「文字の入力より選択肢を出す（ピッカー、メニューなど）」。「値はその場で確かめる」 | 本文で確認 | Entering data |
| ③への当てはめ | 生まれ年・性別・活動量は選択肢で選ばせる。ヘルスケアから取れた項目は③に出さない（出すなら入力済みで）。身長・体重は数値だけ受け付ける形式にし、ありえない値はその場で知らせる | 本文からの読み取り | 同上 |
| 確認画面を置かないこと | Feedback: 「大事な操作が終わったことを、意味があるときは知らせる」。「人は成功を当然と考えるので、知る必要があるのは失敗のとき」。確認画面を挟まず、選んだら確定して、カードが目標の要約に変わるなどで終わったことを伝えれば足りる | 前半は本文で確認、後半は本文からの読み取り | Feedback |

## 実装で守ること

カード内で進める形をとるときの一覧。［　］内は根拠。

**カードの開閉と再開**
- [ ] カードのタップで広げる。広がるのはタップへの応答のときだけにし、ヘルスケアの結果が返った瞬間などに大きく高さが変わらないようにする［Collections］
- [ ] 広げたとき、カード全体（少なくとも今のページと進むボタン）が見えるよう、必要な分だけ自動でスクロールする［Scroll views の自動スクロール］
- [ ] どのページでも見える「閉じる」を置く。閉じても入力を捨てず、確認も出さない。次に開いたら途中のページから始める［Modality の「閉じる手段を明らかに」、Feedback、Launching］
- [ ] カードの見出しで、何の作業かを示す（例: 「目標を立てる」）［Modality］

**ページと手順の表示**
- [ ] 1ページに1つの問い。道は1本（分かれ道や入れ子を作らない）［Modality、Accessibility］
- [ ] 2ページ目以降に「戻る」を置く。「戻る」と「閉じる」を見間違えない見た目・位置にする［Modality の「閉じるボタンと取り違えるボタンを置かない」］
- [ ] 進むボタンは、必要な入力がそろうまで押せない［Entering data］
- [ ] 横にページを切り替えるのは可。カードの中で縦スクロールさせない［Scroll views］
- [ ] 残りの手順は「2/3」のような文字か、押せない点で出す。操作できる Page control を置いて先へ飛べるようにしない［Page controls の説明からの読み取り］
- [ ] 手順の総数は実際と合わせる。③が要らないと分かったら数を直す［Progress indicators の「正確に」からの読み取り］
- [ ] ヘルスケアの読み取りや案の計算で待つときは、回る表示と具体的な一文を出す［Progress indicators］

**ヘルスケアの許可**
- [ ] isHealthDataAvailable() が偽なら②を飛ばす［Setting up HealthKit］
- [ ] 向きを選んだら、そのままシステムの許可画面を出す。許可の前に独立した説明ページを作らない。説明は向きのページの一文と、使用目的の文で行う［HealthKit（HIG）、Privacy の Pre-alert］
- [ ] 使用目的の文は、何のために何を読むかを、能動の完結した文で書く［Privacy］
- [ ] 求める種類は目標の計算に要るものだけ。書き込みの許可は、書き込む機能を使うときに求めることも検討する［Privacy、App Store Review Guidelines 5.1.1(iii)、Authorizing access to health data］
- [ ] ③の要否は「取れたかどうか」で決める。「許可されませんでした」とは書かない［Authorizing access to health data］
- [ ] 許可しなくても③で入力して目標を立て終えられる［App Store Review Guidelines 5.1.1(iv)］
- [ ] 画面の文言は「ヘルスケア」「Apple Health」。「HealthKit」と書かない［HealthKit（HIG）］
- [ ] アプリ内に許可を切り替えるスイッチを作らない［HealthKit（HIG）］

**入力と確定**
- [ ] ③は取れなかった項目だけを1ページに出す。選べるものは選択肢にし、数値は形式を決めてその場で確かめる［Entering data］
- [ ] 案を選んだら確定してよい。カードが目標の要約に変わるなどで、確定したことが分かるようにする［Feedback］
- [ ] 確定したあとで目標を切り替える経路（目標の画面の「目標を切り替える」）を保つ［本文からの読み取り。確認画面を省く前提］

**アクセシビリティ**
- [ ] 視差効果を減らす設定のときは、横のページ移動やカードの拡大をフェードに置き換える［Accessibility、Motion］
- [ ] アニメーションが終わるのを待たせない［Motion の「動きを取り消せるように」］
- [ ] VoiceOver で、カードが広がったこと、今のページの問い、残りの手順の数が読まれるようにする［Accessibility、Feedback の「すべてのフィードバックを利用しやすく」］

**シートで出す形をとる場合（参考）**
- 高さは large のみ。題を付ける。1つ目のページは左上に閉じる、2つ目以降は左上に戻る（閉じるは下へのスワイプ）。Done は置かない［Sheets］
- ヘルスケアの許可シートが自前のシートの上に重なることをどう扱うか（重ねてよいとみなすか、許可を求める前にシートを閉じるか）を決める［Sheets の「一度に1つ」］

## 出典一覧

HIG（本文は JSON で取得。2026-09-24）
- Modality: https://developer.apple.com/design/human-interface-guidelines/modality
- Sheets: https://developer.apple.com/design/human-interface-guidelines/sheets
- Onboarding: https://developer.apple.com/design/human-interface-guidelines/onboarding
- Launching: https://developer.apple.com/design/human-interface-guidelines/launching
- Progress indicators: https://developer.apple.com/design/human-interface-guidelines/progress-indicators
- Page controls: https://developer.apple.com/design/human-interface-guidelines/page-controls
- Disclosure controls: https://developer.apple.com/design/human-interface-guidelines/disclosure-controls
- Lists and tables: https://developer.apple.com/design/human-interface-guidelines/lists-and-tables （展開・複数手順についての記述なしの確認に使用）
- Collections: https://developer.apple.com/design/human-interface-guidelines/collections
- Scroll views: https://developer.apple.com/design/human-interface-guidelines/scroll-views
- Entering data: https://developer.apple.com/design/human-interface-guidelines/entering-data
- Feedback: https://developer.apple.com/design/human-interface-guidelines/feedback
- Privacy: https://developer.apple.com/design/human-interface-guidelines/privacy
- HealthKit: https://developer.apple.com/design/human-interface-guidelines/healthkit
- Motion: https://developer.apple.com/design/human-interface-guidelines/motion
- Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility

Apple の開発者向けドキュメント
- Authorizing access to health data: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data
- requestAuthorization(toShare:read:completion:): https://developer.apple.com/documentation/healthkit/hkhealthstore/requestauthorization(toshare:read:completion:)
- authorizationStatus(for:): https://developer.apple.com/documentation/healthkit/hkhealthstore/authorizationstatus(for:)
- Protecting user privacy: https://developer.apple.com/documentation/healthkit/protecting-user-privacy
- Setting up HealthKit: https://developer.apple.com/documentation/healthkit/setting-up-healthkit

App Store Review Guidelines（2.5.1、5.1.1(ii)〜(iv)、5.1.3）
- https://developer.apple.com/app-store/review/guidelines/
- 注: 依頼にあった「27.x HealthKit」という番号の項は現行の本文に無い。HealthKit に関する規定は 2.5.1（健康・フィットネスの目的で使い、ヘルスケアと連携する）と 5.1.3（Health and Health Research）にある。
