---
version: alpha
name: nu-tori
description: 食事を撮って記録し、体重の傾向から1日の目安を調整する iPhone アプリの見た目。iOS の標準の見た目をそのまま使い、P・F・C の3色だけを自前で持つ。
colors:
  primary: "#6155F5"
  primary-dark: "#6D7CFF"
  on-primary: "#FFFFFF"
  background: "#F2F2F7"
  background-dark: "#000000"
  surface: "#FFFFFF"
  surface-dark: "#1C1C1E"
  on-surface: "#000000"
  on-surface-dark: "#FFFFFF"
  on-surface-secondary: "rgba(60, 60, 67, 0.6)"
  on-surface-secondary-dark: "rgba(235, 235, 245, 0.6)"
  on-surface-tertiary: "rgba(60, 60, 67, 0.3)"
  on-surface-tertiary-dark: "rgba(235, 235, 245, 0.3)"
  fill: "#EFEFF0"
  fill-dark: "#323236"
  separator: "rgba(60, 60, 67, 0.29)"
  separator-dark: "rgba(84, 84, 88, 0.6)"
  error: "#FF383C"
  error-dark: "#FF4245"
  protein: "#F07F1A"
  protein-dark: "#E8903A"
  fat: "#15803D"
  fat-dark: "#228C48"
  carbohydrate: "#2C7BE5"
  carbohydrate-dark: "#4290F4"
  ring-track: "#E5E5EA"
  ring-track-dark: "#2C2C2E"
typography:
  title-2:
    fontFamily: SF Pro
    fontSize: 22px
    fontWeight: 400
    lineHeight: 28px
  headline:
    fontFamily: SF Pro
    fontSize: 17px
    fontWeight: 600
    lineHeight: 22px
  body:
    fontFamily: SF Pro
    fontSize: 17px
    fontWeight: 400
    lineHeight: 22px
  subheadline:
    fontFamily: SF Pro
    fontSize: 15px
    fontWeight: 400
    lineHeight: 20px
  subheadline-emphasized:
    fontFamily: SF Pro
    fontSize: 15px
    fontWeight: 600
    lineHeight: 20px
  footnote:
    fontFamily: SF Pro
    fontSize: 13px
    fontWeight: 400
    lineHeight: 18px
  caption-1:
    fontFamily: SF Pro
    fontSize: 12px
    fontWeight: 400
    lineHeight: 16px
  caption-2:
    fontFamily: SF Pro
    fontSize: 11px
    fontWeight: 400
    lineHeight: 13px
rounded:
  xs: 2px
  sm: 4px
  md: 10px
  lg: 12px
  xl: 18px
  full: 9999px
spacing:
  margin: 16px
  card-padding: 16px
  card-gap: 12px
  section-gap: 24px
  control-gap: 12px
  touch-target: 44px
  ring-strip: 28px
  ring-strip-stroke: 4.5px
  ring-large: 128px
  ring-large-stroke: 14px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.subheadline-emphasized}"
    rounded: "{rounded.full}"
    height: 36px
  button-secondary:
    backgroundColor: "{colors.fill}"
    textColor: "{colors.primary}"
    typography: "{typography.subheadline-emphasized}"
    rounded: "{rounded.full}"
    height: 36px
  button-destructive:
    textColor: "{colors.error}"
    typography: "{typography.body}"
  list:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.md}"
  list-row:
    textColor: "{colors.on-surface}"
    typography: "{typography.body}"
    height: 44px
    padding: 16px
  list-row-editable-value:
    textColor: "{colors.primary}"
    typography: "{typography.body}"
  timeline-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.subheadline}"
    rounded: "{rounded.lg}"
    padding: 16px
  own-record-card:
    backgroundColor: "color-mix(in srgb, #6155F5 10%, #FFFFFF)"
    textColor: "{colors.on-surface}"
    typography: "{typography.subheadline}"
    rounded: "{rounded.lg}"
    padding: 16px
  own-message-bubble:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.subheadline}"
    rounded: "{rounded.xl}"
    padding: 12px
  reply-message:
    textColor: "{colors.on-surface}"
    typography: "{typography.subheadline}"
  composer-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface-tertiary}"
    typography: "{typography.body}"
    rounded: "{rounded.xl}"
    height: 36px
  composer-camera:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.full}"
    size: 44px
  composer-weight:
    backgroundColor: "{colors.fill}"
    textColor: "{colors.primary}"
    rounded: "{rounded.full}"
    size: 44px
  composer-weight-unrecorded:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
  composer-send:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.full}"
    size: 28px
  preset-chip:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.on-surface}"
    typography: "{typography.footnote}"
    rounded: "{rounded.full}"
    height: 32px
    padding: 12px
  value-field:
    backgroundColor: "{colors.fill}"
    textColor: "{colors.on-surface}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: 12px
  value-field-focused:
    backgroundColor: "{colors.surface}"
  estimate-badge:
    textColor: "{colors.on-surface-secondary}"
    typography: "{typography.caption-2}"
    rounded: "{rounded.sm}"
  stepper-button:
    backgroundColor: "{colors.fill}"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    size: 44px
  nutrient-key-protein:
    backgroundColor: "{colors.protein}"
    rounded: "{rounded.xs}"
    size: 9px
  nutrient-key-fat:
    backgroundColor: "{colors.fat}"
    rounded: "{rounded.xs}"
    size: 9px
  nutrient-key-carbohydrate:
    backgroundColor: "{colors.carbohydrate}"
    rounded: "{rounded.xs}"
    size: 9px
  day-ring-strip:
    backgroundColor: "{colors.ring-track}"
    size: "{spacing.ring-strip}"
  day-ring-large:
    backgroundColor: "{colors.ring-track}"
    size: "{spacing.ring-large}"
    typography: "{typography.title-2}"
---

# nu-tori

## Overview

栄養を知らなくても、測って撮るだけで、体が目標に近づいていく手応えを持てるアプリ。ユーザーに求める操作は、朝に体重を入れることと、食べるときに撮ることの2つだけ。見た目は淡々と記録できること、責めないこと、手応えがあることを目指す。

見た目は iOS の標準をそのまま使う。部品は SwiftUI の標準、色は P・F・C を除いてシステムの色、アイコンは SF Symbols、文字はシステムのフォント。新しい iOS にビルドし直すだけで見た目が追従する。自前で持つのは、P・F・C の3色と、1日の丸の描き方だけ。

判断に迷ったら、次の順で上にあるものを取る（`docs/adr/0001-design-principles-order.md`）。ユーザーの操作を増やさない、先回りして気を利かせる、値の確かさに応じて受け付け方を変える、仕組みを言い訳にしない、求められていないことは言わない、モードレス、専用の画面より小さな機能の組み合わせ、拡張性。

## Colors

トークンはライトの値で、`-dark` の付いたものがダークの値。実装ではシステムの色（`Color.accentColor`、`systemGroupedBackground` など）を使い、ここの値はその見本。P・F・C だけはアセットカタログの色として持つ。

- **Primary（systemIndigo、#6155F5）**: 押せるもの、その場で直せる値、自分の発言。システムの色のうち、白の地で 4.5:1 を超える（5.09:1）のは systemIndigo だけで、小さい文字にも使える。C の青と紛れない
- **Background（systemGroupedBackground）と Surface（secondarySystemGroupedBackground）**: 灰色の地に白い一覧とカードを載せる
- **On Surface（label、secondaryLabel、tertiaryLabel）**: 文字はシステムの3段の色だけを使う
- **Fill（tertiarySystemFill）**: 灰色のボタン、値の欄、ステッパーの地。システムの色は半透明なので、トークンは Surface に載せたときの色にしている
- **Error（systemRed）**: 戻せない操作（削除）だけに使う
- **Protein・Fat・Carbohydrate（オレンジ・緑・青）**: FoodNoms と同じ色相。システムの色のままでは1型・2型の色覚で P と F が近く見えるので、P を明るく、F を暗くして明るさの差で見分ける。3色のどの組も、色覚の型を問わずライトとダークの両方で見分けられる。High Contrast の版をアセットカタログに用意する（ライトは白の地で 4.5:1 以上）
- 色を使うのは Primary、Error、P・F・C だけ。状態（間に合うペースか）は色で分けず、文で示す

## Typography

システムのフォント（San Francisco、日本語はヒラギノ）を iOS のテキストスタイルで使い、Dynamic Type に従う。トークンの大きさは Dynamic Type の既定の大きさ。数字は桁をそろえる（`monospacedDigit()`）。

- **Title 2**: 体重の値、大きな1日の丸の中の kcal
- **Headline**: ナビゲーションバーの題、カードの見出し
- **Body**: 一覧の行、値の欄、入力欄
- **Subheadline**: タイムラインのカードの本文、会話、食事の名前、ボタン（ボタンは太字）
- **Footnote**: 一覧の見出しと注記、kcal と P・F・C の小さな数字
- **Caption 1・2**: 時刻、帯の曜日、グラフの目盛り、推定の印
- Large Title は使わない。タイムラインの題はいま見ている日付にする

## Layout

HIG は余白の値を表で決めず、余白をそろえること、セーフエリアを守ること、システムのレイアウトガイドを使うことを求めている。余白は SwiftUI の標準（`.padding()` の既定値、`List` の余白、`VStack`・`HStack` の既定の間隔）に任せ、自前の数値を持たない。Dynamic Type で文字を大きくしても、余白が合わせて変わる。

spacing のトークンは、見本を描くときの値。画面の端とカードの内側は 16、カードの間は 12、まとまりの間は 24。

- **押せる範囲は 44 以上**: 見た目が小さい部品（プリセットのチップ、文字のボタン）も、押せる範囲は `contentShape` で 44 以上に広げる
- **枠のある部品の間は 12 以上**: ステッパーの − と ＋ と値、入力欄のカメラ・体重・書く欄、並べたボタンの間。枠のない部品（文字のボタン）のまわりは 24 ほど空ける

## Elevation & Depth

影は付けない。灰色の地（Background）と白いカード・一覧（Surface）の明るさの差で重なりを示す。シートとバーは iOS の標準の材質を使う。

## Shapes

- **一覧**: iOS の設定と同じ、角の丸い一覧（Inset Grouped、10）
- **タイムラインのカード**: 角の丸い白いカード（12）
- **ボタン**: 塗ったボタンと灰色のボタンは、iOS の標準の形（カプセル）
- **1日の丸**: 1本の輪を、P・F・C の kcal で起点（上）から時計回りに色分けし、一周で1日の目安にする。P・F・C の kcal は、その日の kcal をその日の P×4 : F×9 : C×4 の比で分けた値（kcal の数え方は `server/AGENTS.md` の「端末とサーバーの両方に置く決めごと」）。色の間に細いすき間を空ける。帯の丸は 28・線 4.5、日のまとめの大きな丸は 128・線 14。Swift Charts の `SectorMark`（`innerRadius` と `angularInset`）で描く

## Components

- **ボタン（button-primary、button-secondary）**: 主な操作（記録、始める、この目標で始める）は塗ったボタン（`.borderedProminent`）、並べる副の操作（あとで）は灰色のボタン（`.bordered`）。灰色のボタンの文字は Fill の地で 4.43:1 と 4.5:1 にわずかに届かないが、SwiftUI の標準の見た目を優先してそのまま使う。同じ組み合わせのステッパーの − と ＋、入力欄の体重のボタンは記号なので、記号の基準（3:1）で足りる
- **削除（button-destructive）**: `role: .destructive`。ボタンには削除するものの名前を入れる（「食事を削除」）
- **一覧（list、list-row）**: 押して潜れる行には `chevron.right` を付ける。押してその場で直せる値は Primary で書く（list-row-editable-value）。行を左へ送ると削除が出る（`swipeActions`）
- **タイムラインのカード（timeline-card）**: 食事、知らせ、週の振り返り。アプリからの知らせは全幅の白いカード
- **入力欄（composer-field、composer-camera、composer-weight、composer-send）**: タイムラインの下に固定する。カメラと体重は丸いアイコンのボタンで、その日の体重が未記録のあいだだけ体重を Primary で塗る（composer-weight-unrecorded）。書く欄は1行から始まり5行まで伸び、「送る」は文字を入れたときだけ欄の右端に出す
- **プリセット（preset-chip）**: 入力欄の上に並べる、角の丸いチップ。押せる範囲は 44 に広げる
- **自分の記録（own-record-card）と自分の発言（own-message-bubble）**: 自分が記録した食事と体重は右に寄せ、Primary を薄く敷いたカードにする。自分が書いた文は Primary の吹き出しで右に寄せる
- **返ってきた発言（reply-message）**: 吹き出しにせず、左の地の上に文で置く
- **値の欄（value-field、value-field-focused）**: 数の値は数字のキーボードを出す。選んでいるときは Surface の地に Primary の枠を付ける
- **押せないボタン**: システムの無効の表示（`.disabled`）に任せる
- **推定の印（estimate-badge）**: 推定したままの料理の量に添える、枠線だけの小さな印。直すと外す
- **推定中**: その食事のカードに回る印と「推定しています…」を出す。画面全体をふさがない
- **ステッパー（stepper-button）**: 体重の − と ＋。見た目も 44。押しているあいだ 0.1 kg ずつ続けて動く
- **1日の丸（day-ring-strip、day-ring-large）**: 目安を超えた日は輪の起点に文字の色の点を付ける。目標がないあいだは P・F・C の割合で一周させる。体重を記録した日は、帯の丸の中に灰色の点を付ける。帯の丸には曜日、大きな丸には kcal と P・F・C の名前を添える
- **P・F・C の印（nutrient-key-protein、nutrient-key-fat、nutrient-key-carbohydrate）**: 見出しや内訳の P・F・C の名前の前に置く色の四角
- **グラフ**: Swift Charts。系列は Primary の1色、目安と目標の道筋は点線、グリッドは薄く。系列が2本あるときは線の端に名前を添える。押した週・日の値は `chartXSelection` で出す
- **アイコン**: SF Symbols の `camera.fill`（撮る）、`scalemass.fill`（体重）、`person.crop.circle`（アカウント）、`chevron.right`（潜れる行）。文字で足りるところにはアイコンを付けない

## Do's and Don'ts

- Do: HIG か SwiftUI に標準があるものは、それに従う。独自の振る舞いを作らない（値が変わる動きは `contentTransition(.numericText())` と `withAnimation`、手応えは `sensoryFeedback`、写真を横に送るのは `TabView` のページ表示、シートと確かめは `sheet`・`confirmationDialog`・`alert`、潜るのは `NavigationStack`）
- Do: モードレスにする。どの操作も途中でやめられ、あとからやり直せる。確認を済ませないと次に進めない作りにしない
- Do: ダイアログは戻せない操作（食事とアカウントの削除）を確かめるときだけ出す。打ち間違いや推定の失敗は、画面を覆わずその場で知らせる
- Do: モードの入れ子は最大3階層に収める
- Do: 確かめのダイアログとシートの否定の操作は「キャンセル」1つにする。バツを並べない
- Do: 開いた画面は操作の対象（食事、体重、会話）から始める。動詞の見出しやタスク名のタブを並べない
- Do: タブを持つときは OS 標準のタブバーを使う
- Do: Android 版を出すときは Android に合わせて UI を作り直す。iOS と無理に共通化しない
- Do: 全画面はカメラのように必然性がある場面に限る
- Do: P・F・C は色だけで示さず、いつも「P」「F」「C」か栄養の名前を添える
- Do: 量は数と単位の間を空ける（「72.4 kg」「510 kcal」）。日付は「9月24日（木）」、期間は「9月18日〜24日」と書く
- Do: ボタンは押すと起きることを動詞で書く（記録、始める、撮る）
- Don't: カスタムフォントを使う
- Don't: 画面に「AI」「質問」「相談」という言葉を出す。推定であることは、推定の印と読み込み中の表現で伝える
- Don't: 間に合わない週を責める。事実だけを書く（「このままだと期限に 0.8 kg 届きません」）
- Don't: 求められていないアドバイスを出す。知らせには、ふだんの様子と次にできることだけを書く
- Don't: 縦軸が2本のグラフを作る（体重と kcal を1つのグラフに重ねない）
- Don't: 1日の丸をアクティビティリングに似せる（輪を何本も重ねる、黒い地に光らせる）
- Don't: 取り消しとやり直しの操作を置く。直した値はいつでも直し直せる
