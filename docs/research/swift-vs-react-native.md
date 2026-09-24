# 初回リリースを Swift（SwiftUI）と React Native（Expo）のどちらで作るか

調査日: 2026-09-24
対象: nu-tori の初回リリース（iPhone のみ）の実装技術。アプリが必要とするものは `docs/ui-design/0001-first-release/` の `index.md`、`05-navigation.md`、`06-layout.md` から拾った

> **確認の方法と限界**
> - Apple の開発者向けドキュメントとリリースノートは、HTML が JavaScript で組み立てられるため、同じ内容の JSON（`https://developer.apple.com/tutorials/data/<パス>.json`）を取得して**本文を直接読んだ**。出典にはふつうの URL を書く。Upcoming Requirements、Software Releases、App Review Guidelines、Apple Developer Program License Agreement は HTML を取得して読んだ。
> - React Native（reactnative.dev）と Expo（docs.expo.dev、expo.dev/changelog、expo.dev/pricing）は HTML を取得して読んだ。バージョンと公開日は npm レジストリ（registry.npmjs.org）で確かめた。
> - 第三者ライブラリは GitHub のリポジトリを clone して、README、CHANGELOG、ソースコード、コミット履歴（作者ごとの数）を読んだ。GitHub の API（スター数、issue 数）はこの環境から使えなかったので、保守状況はコミット履歴と npm の公開日で見た。
> - 本文で確かめた主張は「本文で確認」と書き、短い英語の原文を添える。
> - 本文の記述から推し量ったものは「本文からの読み取り」と書き、何から読み取ったかを添える。エージェントとの相性は、一次情報が少ないため読み取りが多い。
> - 本文を探しても記述が無かったものは「本文を探したが記述なし」と書き、探したページを添える。
> - 実機での確認、試作での確認、性能の計測はしていない。二次情報（ブログ、記事、SNS）は使っていない。Expo の changelog は Expo 社自身の発表なので、Expo についての一次情報として扱った。
> - 状況は速く動いている。とくに 2026-09-14 に iOS 27 と Xcode 27 が出たばかりで、Expo の iOS 27 対応（SDK 58）はまだベータ。ここに書いた対応状況は 2026-09-24 時点のもの。

## 結論の要約

- **おすすめ: Swift（SwiftUI）で作る。**
- 理由は次の4つ。
  1. **新しい iOS の見た目に、その日から素直に追従できる。** Apple は「SwiftUI・UIKit の標準の部品を使えば、最新の SDK でビルドするだけで Liquid Glass の見た目になる」と書いている（本文で確認）。iOS 27 は 2026-09-14 に出たが、Expo の iOS 27 対応版（SDK 58）は 2026-09-24 時点でまだベータで、EAS Build の Xcode 27 のイメージもまだ無い（本文で確認）。React Native でも標準のナビゲーションはネイティブの部品になるが、タイムラインやカードなど自前の画面は React Native のビューで作るため、Liquid Glass などは Expo のモジュールを通して当てることになる（本文からの読み取り）。
  2. **アプリの中心が HealthKit とカメラで、どちらも Apple の API を直接使う方が確実。** React Native には Expo の公式の HealthKit モジュールが無く、第三者のライブラリ（@kingstinct/react-native-healthkit）に頼る。このライブラリは活発に保守されているが、この1年のコミットの大半が1人によるもので、バックグラウンドでの取り込みが「黙って止まる」不具合を最近直している（本文で確認）。他アプリが書いた体重をバックグラウンドで取り込むのは nu-tori の前提なので、ここを第三者の層に預けるのは危険が大きい（本文からの読み取り）。
  3. **React Native の一番の利点（コードの共有）が、この条件では小さい。** Android 版は UI を作り直す前提で、写真からの推定と会話はサーバー側で行う。端末に残る共有できるコードは、API クライアントと、1日の目安の計算などの小さなロジックに限られる（本文からの読み取り）。
  4. **エージェントとの相性は、Swift でも十分に良くなった。** Xcode 26.3 から Claude Code などの外部エージェントが MCP で Xcode のビルド、プレビュー、シミュレータの操作を使える。Xcode 27 ではエージェントがシミュレータを起動し、タップを送り、スクリーンショットで UI を確かめられる（本文で確認）。
- **Swift の主なリスク**
  - Swift も iOS 開発も初めてなので、最初の学習に時間がかかる。React と TypeScript の経験がそのまま使えるのは、宣言的に UI を組む考え方までで、言語、並行処理（Swift Concurrency）、Xcode の使い方は新しく覚える（本文からの読み取り）。
  - ビルドと確認には Mac と Xcode が要る。**クラウドの Linux 環境で動くエージェント（Claude Code on the web など）からは、iOS アプリのビルドもシミュレータでの確認もできない**。エージェントは Mac の上で動かす（本文からの読み取り）。
  - OTA 更新（審査を通さずに JavaScript を差し替える）は使えない。直すたびに審査に出す。
- **React Native（Expo）を選ぶ方がよい場合**（本文からの読み取り）
  - Mac を開発の主な場にできない、またはクラウドのエージェントに開発の大半を任せたい場合。EAS Build はクラウドで iOS アプリをビルドし、TestFlight に出せる。
  - Android 版を早い時期に出す予定で、UI 以外のロジックを端末側に多く持つ設計に変える場合。

## 前提: 2026-09-24 時点のバージョン

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 最新の iOS と Xcode | iOS 27.0 と Xcode 27 が 2026-09-14 に出た。iOS 27.2 beta 2（09-21）、Xcode 27.1 beta・27.2 beta も出ている。Xcode 27 は Swift 6.4 を含み、macOS Tahoe 26.6 以降が要る（"Xcode 27 includes Swift 6.4 … requires a Mac running macOS Tahoe 26.6 or later."） | 本文で確認 | https://developer.apple.com/news/releases/ 、https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes |
| App Store に出すのに要る SDK | 2026-04-28 から、Xcode 26 以降と iOS 26 SDK 以降でビルドしたものしか受け付けない。2026-09-09 から、iOS 13 以降を対象にする必要がある | 本文で確認 | https://developer.apple.com/news/upcoming-requirements/ |
| iOS 27 SDK での大きな変更 | 「最新の SDK でビルドしたアプリは、シーンベースのライフサイクルを採らないと起動しない」（"Apps built with the latest SDK must adopt the scene-based life cycle or they fail to launch."） | 本文で確認 | https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes |
| React Native の最新 | 0.87.1（npm、2026-08-26）。0.87 は 2026-08-11 に出た。0.88 は RC | 本文で確認 | https://reactnative.dev/blog/2026/08/11/react-native-0.87 、npm の react-native |
| Expo の最新 | 安定版は SDK 57（2026-06-30、React Native 0.86）。npm の expo@57.0.24（09-18）。SDK 58 はベータ（09-15、React Native 0.88 RC） | 本文で確認 | https://expo.dev/changelog/sdk-57 、https://expo.dev/changelog/sdk-58-beta 、https://docs.expo.dev/versions/latest/ |
| New Architecture | React Native 0.82 から New Architecture だけになった（"making it the only architecture for this and future versions"）。0.84 から iOS のビルドに旧アーキテクチャのコードを含めない | 本文で確認 | https://reactnative.dev/blog/2025/10/08/react-native-0.82 、https://reactnative.dev/blog/2026/02/11/react-native-0.84 |
| React Native は Expo と組むのが前提か | React Native 公式は、新しく作るならフレームワーク（Expo など）を使うことを勧めている（"if you're building a new app with React Native, we recommend using a Framework"） | 本文で確認 | https://reactnative.dev/docs/environment-setup |

## 問い1: 機能ごとの実現性

### HealthKit

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Swift での読み書き、修正・削除の反映 | HealthKit は公式の API。食事は food の相関型（栄養の複数のサンプルを1つの食べ物にまとめる）で書ける（"Food correlation types combine any number of nutritional samples into a single food object."）。HKAnchoredObjectQuery は追加に加えて削除も返すので、他アプリでの修正・削除を取り込める（"returns an anchor value that corresponds to the last sample or deleted object received"） | 本文で確認 | https://developer.apple.com/documentation/healthkit/hkcorrelationtypeidentifier/food 、https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery |
| バックグラウンドでの取り込みの要件 | 「バックグラウンド配信をするなら、observer query を application(_:didFinishLaunchingWithOptions:) で全部用意する」。処理が済んだら完了ハンドラを呼ぶ。3回応答しないと配信が止まる（"If your app fails to respond three times, HealthKit assumes your app can't receive data and stops sending background updates."）。専用の entitlement が要る。シミュレータでは試せない | 本文で確認 | https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:) |
| React Native に公式の HealthKit モジュールはあるか | Expo SDK の一覧（docs.expo.dev のリファレンス）に HealthKit（Health）のモジュールは無い。Pedometer はある | 本文を探したが記述なし（Expo SDK のリファレンスの一覧） | https://docs.expo.dev/versions/latest/ |
| 第三者のライブラリ | @kingstinct/react-native-healthkit 16.0.0（2026-09-18）。量・カテゴリ・相関（食べ物を含む）の読み書き、anchor による変更と削除の取得、`deleteObjects` による削除、変更の購読がある。Expo の config plugin があり、`background: true` で entitlement を付ける。Expo Go では動かず、開発ビルドが要る | 本文で確認 | https://github.com/kingstinct/react-native-healthkit （README） |
| 同ライブラリの New Architecture 対応 | react-native-nitro-modules に移った（"The library has been migrated to react-native-nitro-modules."）。iOS 27 の新しい型と、iOS 27 の「限られた期間だけ許可」に対応する `getEarliestAuthorizedSampleDates` を 16.0.0 で足している | 本文で確認 | 同上（README、packages/react-native-healthkit/CHANGELOG.md） |
| 同ライブラリのバックグラウンド配信 | `configureBackgroundTypes` で種類を UserDefaults に保存し、起動時にネイティブ側で observer を登録する（"registered natively at launch … so background delivery survives app termination"）。ただし 15.x までは、公開した config plugin がソースより古く、「アプリが終了されたあと observer が登録し直されなかった」（"were not re-registered after the app was terminated"）。15.1.0 で直った | 本文で確認 | 同上（src/specs/CoreModule.nitro.ts、CHANGELOG.md の 15.1.0） |
| 同ライブラリの保守の体制 | 2025-09-24〜2026-09-24 のコミット 288 件のうち、194 件が1人（Robert Herber）。残りの多くは bot | 本文で確認（git log を数えた） | 同上（コミット履歴） |
| もう1つの定番ライブラリ | react-native-health は最後のリリースが 1.19.0（2024-10-15）で、それ以降コミットが無い | 本文で確認 | https://github.com/agencyenterprise/react-native-health 、npm の react-native-health |
| React Native でのバックグラウンド取り込みの見通し | ネイティブ側の observer 登録はライブラリがやるが、取り込んだ体重をアプリのデータに反映する処理を JavaScript で書くなら、バックグラウンドで起こされた短い時間に JavaScript の実行環境が立ち上がって完了ハンドラまで届く必要がある。Swift なら、起動処理の中で直接書ける。バックグラウンドの挙動は実機でしか試せないので、React Native では確かめる手間も増える | 本文からの読み取り（enableBackgroundDelivery の要件と、ライブラリの実装から） | 上の2つ |

### カメラ、写真ライブラリ

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Swift でのファインダー | AVFoundation の AVCaptureVideoPreviewLayer を使う。SwiftUI はレイヤーを直接置けないので、UIView に包んで置く（Apple のサンプル AVCam: "SwiftUI doesn't support using layers directly, so instead, the app hosts this layer in a UIView subclass"）。SwiftUI にそのまま置ける公式のプレビュー部品は見当たらない | 前半は本文で確認、後半は本文を探したが記述なし（SwiftUI の索引で camera・capture を検索） | https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app 、https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer |
| React Native でのファインダー | expo-camera（Expo 公式、57.0.5）の CameraView を置ける。`active` で止める・動かす、`pausePreview`／`resumePreview` がある。撮った写真に EXIF を付けられる。「同時に動かせるプレビューは1つ」（"Only one Camera preview can be active at any given time."） | 本文で確認 | https://docs.expo.dev/versions/latest/sdk/camera/ |
| より高機能な第三者ライブラリ | react-native-vision-camera 5.2.3（2026-08-20）。V5 が出て V4 は保守を終えた（"VisionCamera V4 is no longer actively maintained."）。この1年のコミットの大半は1人（Marc Rousavy） | 本文で確認 | https://github.com/mrousavy/react-native-vision-camera |
| タイムラインの上に常に置けるか | どちらも、ファインダーはネイティブのビューで、縦スクロールの一番上に置ける。nu-tori はファインダーが1つなので expo-camera の制約に当たらない。常に動かすときの電池と発熱は、どちらでも実機で確かめる | 本文からの読み取り | 上の2つ |
| 写真を選んで撮影時刻を読む | Swift: PhotosPicker（iOS 16 から）。写真ライブラリを渡さないと itemIdentifier は nil（"This value is nil if you create a Photos picker without a photo library."）。時刻は画像の EXIF か、PHAsset から読む。React Native: expo-image-picker の `exif: true` で EXIF を受け取れる。`assetId` は「限られた写真だけ許可」のとき null になりうる | 本文で確認 | https://developer.apple.com/documentation/photosui/photospicker 、https://developer.apple.com/documentation/photosui/photospickeritem/itemidentifier 、https://docs.expo.dev/versions/latest/sdk/imagepicker/ |

### Sign in with Apple、ローカル通知、サーバーの呼び出し

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Sign in with Apple | Swift は AuthenticationServices を直接使う。React Native は expo-apple-authentication（Expo 公式）。ボタンはネイティブの ASAuthorizationAppleIDButton（"using the native ASAuthorizationAppleIDButton"） | 本文で確認（Expo 側） | https://docs.expo.dev/versions/latest/sdk/apple-authentication/ |
| ローカル通知 | Swift は UserNotifications を直接使う。React Native は expo-notifications の `scheduleNotificationAsync` | 本文で確認（Expo 側） | https://docs.expo.dev/versions/latest/sdk/notifications/ |
| サーバーの AI 推定の呼び出し | どちらも HTTP を呼ぶだけで、特別な部品は要らない。React Native なら Web で使っている fetch や型の書き方をそのまま使える | 本文からの読み取り | — |

### ナビゲーション、その場で広げるカード、アクセシビリティ

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| React Native でプッシュ・シートがネイティブになるか | Expo Router の Stack は React Navigation の native stack で、その下の react-native-screens は UINavigationController の派生クラスを使う（`@interface RNSNavigationController : UINavigationController`）。presentation に `formSheet` などがある | 本文で確認 | https://docs.expo.dev/router/advanced/stack/ 、https://github.com/software-mansion/react-native-screens （ios/legacy/RNSScreenStack.h） |
| React Native でアラートがネイティブになるか | React Native の Alert は「アラートのダイアログを出す」API で、iOS ではボタンごとに種類（破壊的な操作、キャンセルなど）を指定できる。中で UIAlertController を使うとまでは書かれていない | 前半は本文で確認、後半は本文を探したが記述なし | https://reactnative.dev/docs/alert |
| タイムラインの中でカードを広げ、ページ送りする | HIG にこの形の標準の部品は無い（`docs/research/hig-inline-goal-setup.md`）。どちらで作っても自前の部品になる。Swift なら ScrollView のページ送り（`scrollTargetBehavior(.paging)`、iOS 17 から）とアニメーションを組み合わせる。React Native なら ScrollView のページ送りと Reanimated のレイアウトアニメーションを組み合わせる | 前半は既存の調査で確認、後半は本文からの読み取り | https://developer.apple.com/documentation/swiftui/view/scrolltargetbehavior(_:) 、https://developer.apple.com/documentation/swiftui/pagingscrolltargetbehavior |
| Reduce Motion | Swift: `accessibilityReduceMotion`（"Whether the system preference for Reduce Motion is enabled."）。React Native: `AccessibilityInfo.isReduceMotionEnabled()`、Reanimated の `useReducedMotion` | 本文で確認 | https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion 、https://reactnative.dev/docs/accessibilityinfo |
| VoiceOver | どちらも対応の API がある。React Native は VoiceOver と TalkBack に合わせた API を持つ（"React Native has complementary APIs"）。ただし React Native の文書にも、入れ子の要素が VoiceOver で読まれない場合があると書かれている | 本文で確認 | https://reactnative.dev/docs/accessibility |

## 問い2: HIG への準拠と、新しい iOS の見た目への追従

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| 標準の部品を使えば Liquid Glass になるか | 「SwiftUI、UIKit、AppKit の標準の部品を使っていれば、最新のプラットフォームで最新の見た目になる」（"If your app uses standard components from SwiftUI, UIKit, or AppKit, your interface picks up the latest look and feel"）。バー、シート、ポップオーバー、コントロールは自動でこの素材になる | 本文で確認 | https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass |
| 自前の部品に Liquid Glass を当てる | SwiftUI は `glassEffect(_:in:)`（iOS 26 から）。UIKit は UIGlassEffect | 本文で確認 | https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) 、Adopting Liquid Glass |
| React Native での Liquid Glass | Expo Router のナビゲーションヘッダーは iOS 26 から Liquid Glass になる（ネイティブのバーのため）。自前のビューには expo-glass-effect の GlassView（UIVisualEffectView を使う）を使う。GlassView は iOS 26 以上だけで、それ以外は普通の View になる。GlassView や親の opacity を 0 にすると効果が出ないなどの注意がある | 本文で確認 | https://docs.expo.dev/router/advanced/stack/ 、https://docs.expo.dev/versions/latest/sdk/glass-effect/ |
| SwiftUI の部品を React Native から使う | @expo/ui の SwiftUI 部品を Host の中に置ける。中身は UIHostingController（"Under the hood, it uses UIHostingController"）。SDK 58 ベータで NavigationStack などが足された。足りない部品は Swift で自分で書く（"Extending with SwiftUI"） | 本文で確認 | https://docs.expo.dev/guides/expo-ui-swift-ui/ 、https://expo.dev/changelog/sdk-58-beta |
| 前回（iOS 26）の追従の速さ | Expo SDK 54 は 2025-09-10 に出て、iOS 26（2025-09-15）より前に Liquid Glass のアイコン、GlassView、ネイティブのタブに対応した | 本文で確認 | https://expo.dev/changelog/sdk-54 |
| 今回（iOS 27）の追従の速さ | iOS 27 は 2026-09-14 に出た。Expo SDK 58（iOS 27 向け）は 09-15 にベータが出て、安定版は React Native 0.88 の安定版を待つ。SDK 57 で Xcode 27 を使うには、シーン対応を明示的に有効にする（`ios.enableSceneSupport`）。EAS Build の最新イメージは Xcode 26.6 で、Xcode 27 のイメージは「近日」（"coming soon"）。2026-09-24 に EAS のインフラの文書を見ても Xcode 27 は載っていない | 本文で確認 | https://expo.dev/changelog/sdk-58-beta 、https://expo.dev/changelog/sdk-57 、https://docs.expo.dev/build-reference/infrastructure/ |
| 追従の差の意味 | Swift は、新しい Xcode が出た日から、新しい SwiftUI の API をそのまま使える。React Native は、React Native 本体、Expo、使っている第三者ライブラリの3層がそろうのを待つか、足りない分を Swift で書く。nu-tori は「その時点の標準の見た目にどれだけ早く、素直に追従できるか」を条件にしているので、Swift が有利 | 本文からの読み取り（上の各行から） | — |

## 問い3: 性能

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Swift と React Native を比べた公式の計測 | Apple、React Native、Expo のどの文書にも、同じアプリで比べた数字は無い | 本文を探したが記述なし（上に挙げた各ページ、React Native のリリースの記事） | — |
| React Native の最近の改善 | 0.84 で Hermes V1 が既定になり、性能が大きく上がったと書いている。一方で、SDK 56〜57 では Hermes V1 の不具合で、Reanimated などを使うアプリのメモリが大きく増える問題があり、expo@57.0.9 で直った | 本文で確認 | https://reactnative.dev/blog/2026/02/11/react-native-0.84 、https://expo.dev/changelog/sdk-57 |
| nu-tori にとっての性能 | 重い処理（写真からの推定、会話）はサーバーで行う。端末で重いのは、ファインダー（どちらもネイティブ）と、長いタイムラインのスクロールと、カードのアニメーション。React Native でも足りる見込みだが、Swift の方が層が少なく、問題が出たときに原因を追いやすい | 本文からの読み取り | — |

## 問い4: ビルドと配布

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Swift のビルドと配布 | Xcode でビルドし、App Store Connect（TestFlight、審査）に出す。Xcode 27 は macOS Tahoe 26.6 以降の Mac が要る | 本文で確認（Mac の要件） | https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes |
| EAS Build と EAS Submit | クラウドで iOS をビルドし、ストアに出せる。無料プランは月に iOS 15 回・Android 15 回のビルド、低い優先度、45分で打ち切り。Starter は月 19 ドル＋使った分 | 本文で確認 | https://expo.dev/pricing |
| HealthKit を使うと Expo Go で試せない | ライブラリの README に「Expo Go では動かない。開発ビルドを自分で作る」とある。Expo 自身も、Expo Go は学習用で、出すアプリは開発ビルドで作るよう勧めている | 本文で確認 | https://github.com/kingstinct/react-native-healthkit 、https://expo.dev/changelog/expo-go-and-app-store-may-2026 |
| OTA 更新 | EAS Update で JavaScript、スタイル、画像を差し替えられる。ネイティブのコードや依存を変えるときは使えない | 本文で確認 | https://docs.expo.dev/eas-update/introduction/ |
| OTA 更新と Apple の規約 | 審査ガイドライン 2.5.2: 「機能を加えたり変えたりするコードをダウンロードして実行してはならない」。Apple Developer Program License Agreement 3.3.1(B): インタープリタのコードは、主な目的を変えない、署名やサンドボックスを迂回しない、などの条件でダウンロードしてよい。Expo も「更新もストアの規約に従う。挙動の変更は通常は審査を通すべき」と書いている | 本文で確認 | https://developer.apple.com/app-store/review/guidelines/ 、https://developer.apple.com/support/terms/apple-developer-program-license-agreement/ 、https://docs.expo.dev/eas-update/faq/ |
| OTA 更新の価値 | 一人開発では、JavaScript の不具合を審査を待たずに直せるのは大きな利点。ただし機能の追加には使えないので、「直す」だけの道具と考える | 本文からの読み取り（上の規約から） | — |

## 問い5: 長期の保守

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Swift で OS 更新ごとにすること | Xcode を上げ、非推奨と変更に合わせる。iOS 27 の例: シーンベースのライフサイクルの必須化、`@State` の実装の変更（初期値の書き方によってはコンパイルできなくなる） | 本文で確認 | https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes |
| React Native で更新ごとにすること | Expo SDK は年に3回（SDK 57 からは間に小さな版も試している）、React Native は年に6回。SDK の保守は約1年（"SDK releases will continue to have a lifetime of approximately one year"）。上げるたびに開発ビルドを作り直す。React Native 0.87 は TypeScript の型を厳しい版に切り替えた（0.88 まで元に戻せる） | 本文で確認 | https://expo.dev/changelog/sdk-57 、https://reactnative.dev/blog/2026/08/11/react-native-0.87 |
| 依存の多さ | nu-tori を React Native で作ると、少なくとも React Native、Expo の各モジュール（camera、image-picker、apple-authentication、notifications、glass-effect、router、updates）、react-native-screens、Reanimated、HealthKit のライブラリと Nitro に依存する。Swift なら Apple のフレームワークだけで作れる | 本文からの読み取り（各ライブラリの文書から） | 上の各ページ |
| OS 更新と React Native の両方の変更 | iOS 27 のシーン対応は、Apple の変更が React Native 側の変更を求めた例。Swift なら自分のコードだけを直せばよいが、React Native では Expo の対応を待つか、設定で有効にする | 本文で確認（前半）、本文からの読み取り（後半） | https://expo.dev/changelog/sdk-57 、https://expo.dev/changelog/sdk-58-beta |

## 問い6: AI コーディングエージェントとの相性

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Xcode と外部のエージェント | Xcode 26.3 から、Anthropic の Claude Agent と OpenAI の Codex を使った agentic coding に対応し、MCP で Xcode の機能を外部のエージェントに出す。Claude Code には `claude mcp add --transport stdio xcode -- xcrun mcpbridge` で足す。`AGENTS.md`・`CLAUDE.md` にヒントを書くことも勧めている | 本文で確認 | https://developer.apple.com/documentation/xcode-release-notes/xcode-26_3-release-notes 、https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode |
| Xcode 27 でエージェントができること | 「シミュレータを起動し、アプリを入れて起動し、タッチを送り、スクリーンショットで UI の振る舞いを確かめる」（"Agents can now boot simulators, install and launch apps, synthesize touch events, and capture screenshots to verify UI behavior."）。プレビューをライト・ダーク、文字サイズ違いで描ける。デバッガ、ビルド設定、entitlement、Info.plist を扱える。Apple 製のスキル（SwiftUI Specialist など）がある | 本文で確認 | https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes 、https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes |
| Xcode のプロジェクトファイル | Xcode 27.2（ベータ）から、プロジェクトの設定を JSON の `.xcproj` で持てる。「エージェントが編集しやすい」（"easier for coding intelligence agents to edit the file for you"） | 本文で確認 | https://developer.apple.com/documentation/xcode/updating-your-xcode-project-configuration-file-format |
| Expo とエージェント | Expo MCP Server が無料プランでも使える（利用量に上限あり）。文書、EAS のビルド、TestFlight のクラッシュを扱い、ローカルのシミュレータでスクリーンショットやタップができる。Claude のコネクタにも載った。SDK 58 ベータでエージェント向けの CLI（@expo/agent-cli、実験的）を出した。Expo の文書は Markdown でも読める | 本文で確認 | https://expo.dev/changelog/the-expo-mcp-server-is-now-available-on-the-free-plan 、https://expo.dev/changelog/connect-expo-in-claude 、https://expo.dev/changelog/sdk-58-beta |
| クラウドのエージェントから iOS をビルドできるか | Expo なら、Linux の上のエージェントからでも EAS Build でクラウドでビルドし、TestFlight に出せる（Expo MCP の例: "Start a production iOS build"、"Submit the latest iOS build to TestFlight"）。Swift の iOS アプリのビルドとシミュレータには Mac と Xcode が要る。Linux でも Swift のツールチェーンは動くので、UI を含まない Swift パッケージ（計算のロジックなど）のテストはできる | 前半は本文で確認、後半は本文からの読み取り（Xcode の要件と、Swift の Linux・Android 向けツールチェーンの文書から） | https://expo.dev/changelog/connect-expo-in-claude 、https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html |
| 言語ごとの書きやすさ | エージェントが TypeScript と Swift のどちらを正しく書きやすいかを示す一次情報は無い。Expo は「Expo Modules 2.0 は独自の DSL をやめて普通の Swift・Kotlin にしたので、モデルがよく知っている」と書いており、Swift が書けること自体は前提にしている | 前半は本文を探したが記述なし、後半は本文で確認 | https://expo.dev/changelog/sdk-58-beta |
| 開発者本人がレビューできるか | React Native なら、エージェントの書いた TypeScript を開発者が自分で読んで直せる。Swift では、はじめのうちはエージェントの出力の良し悪しを見分けにくい。逆に、Swift でもエージェントに説明させながら書くことが学習になる | 本文からの読み取り | — |
| まとめ | どちらも、ビルド、画面の確認、操作までエージェントに任せられる段階にある。違いは「どこで動かすか」: Swift は Mac の上、Expo はクラウドでも可。nu-tori を Mac の上の Claude Code で作るなら、差は小さい | 本文からの読み取り | 上の各行 |

## 問い7: 学習コストと一人開発の総コスト

| 問い | 答え | 確かさ | 出典 |
|---|---|---|---|
| Swift の学習の入口 | Apple は「Develop in Swift Tutorials」（Swift と Xcode でのアプリ開発を学ぶ人向け）と SwiftUI のチュートリアルを出している | 本文で確認 | https://developer.apple.com/tutorials/develop-in-swift 、https://developer.apple.com/tutorials/swiftui |
| React Native の学習 | React と TypeScript の経験がそのまま使える。ただし iOS 固有のこと（HealthKit の許可、entitlement、署名、TestFlight、審査、バックグラウンドの制約）は、どちらを選んでも新しく覚える | 本文からの読み取り | — |
| React Native でも Swift を書くことになるか | 部品が足りないときの道は、Expo UI の「Extending with SwiftUI」や Expo Modules で Swift を書くこと。HealthKit の細かい挙動やバックグラウンドの処理で問題が出たときも、ネイティブのコードを読む必要がある | 本文で確認（Swift で拡張する道があること）、本文からの読み取り（必要になる場面） | https://docs.expo.dev/guides/expo-ui-swift-ui/ 、https://expo.dev/changelog/sdk-58-beta |
| 総コストの見立て | 最初の数週間は React Native の方が速い。以降は、HealthKit とカメラと新しい iOS への追従で React Native に「3層の調整」が加わり、Swift は Apple の変更だけを追えばよい。共有できるコードが小さいので、Android 版を出すときに React Native で得られる分も小さい | 本文からの読み取り | — |

## メリットとデメリットの整理

### Swift（SwiftUI）

- メリット
  - 標準の部品がそのまま最新の見た目（Liquid Glass）になる。新しい iOS の API を出た日から使える
  - HealthKit、AVFoundation、PhotosUI、AuthenticationServices、UserNotifications をすべて公式の API で直接使える。第三者の依存がほぼ要らない
  - バックグラウンドの HealthKit 配信を、Apple の書くとおりの場所（起動処理）に書ける
  - Xcode 26.3 以降、Claude Code から MCP で Xcode のビルド、プレビュー、シミュレータの操作を使える
- デメリット
  - Swift も Xcode も初めて。はじめはエージェントの出力を自分で評価しにくい
  - Mac が必須。クラウドの Linux のエージェントからは iOS のビルドと画面の確認ができない
  - OTA 更新が無い。すべての修正が審査を通る
  - Android 版では UI 以外のロジックも別に書く（Swift SDK for Android や Kotlin Multiplatform は別の道として残る）

### React Native（Expo）

- メリット
  - React と TypeScript の経験がそのまま使える。書かれたコードを自分で読める
  - EAS Build・Submit でクラウドからビルドと配布ができ、Mac に縛られにくい。Expo MCP でエージェントからビルドや TestFlight を扱える
  - EAS Update で JavaScript の不具合を審査なしに直せる
  - Android 版で API クライアントやロジックを共有できる
  - プッシュ、シート、ヘッダーはネイティブ（UINavigationController）になる
- デメリット
  - HealthKit に公式のモジュールが無く、ほぼ1人で保守されているライブラリに頼る。バックグラウンドの取り込みはこの層で不具合が出た実績がある
  - 新しい iOS への対応が、React Native、Expo、第三者ライブラリの3層で遅れうる（iOS 27 では 2026-09-24 時点で Expo の対応版がベータ、EAS に Xcode 27 が無い）
  - タイムラインやカードなど自前の部分は React Native のビューになり、Liquid Glass などは別のモジュールで当てる
  - 依存が多く、年に数回の SDK 更新と開発ビルドの作り直しが続く
  - 足りない部分では結局 Swift を書く

## おすすめ

**Swift（SwiftUI）で初回リリースを作る。**

nu-tori の条件（iPhone だけ、HIG に沿う、Android は UI を作り直す、ヘルスケアとカメラが中心、最新の見た目に素直に追従）は、React Native の利点（コードの共有、Web の知識の再利用、クラウドでのビルド）をほとんど生かさず、弱点（第三者の HealthKit、新しい iOS への追従の遅れ、依存の多さ）に当たる。学習コストは確かに大きいが、それは初めの一度だけで、上の弱点はリリース後も毎年続く。

## 主なリスクと手当て

| リスク | 手当て（本文からの読み取り） |
|---|---|
| Swift の学習に時間がかかる | Develop in Swift と SwiftUI のチュートリアルを最初に通す。エージェントに書かせたコードは、説明させてから取り込む |
| エージェントの書いた Swift を評価できない | Xcode の MCP を Claude Code に足し、ビルド、テスト、プレビューのスクリーンショット、シミュレータでの操作で確かめさせる。`AGENTS.md` に Xcode とプロジェクトのヒントを書く |
| クラウドのエージェント（Linux）から iOS をビルドできない | 画面を伴う作業は Mac の上で行う。計算のロジックは UI から分けた Swift パッケージにし、Linux でもテストできるようにする |
| OTA 更新が無い | TestFlight で身近な人（Tさん・Mさんなど）に先に使ってもらい、審査に出す前に不具合を減らす |
| バックグラウンドの HealthKit 配信は実機でしか試せない | 早い時期に、他アプリで体重を書いてアプリが起こされるかを実機で確かめる（どちらの技術でも必要） |
| 後で Android 版を出すときに共有できるものが無い | API をサーバー側に寄せておく（推定と会話はすでにサーバー側）。共有の手段（Swift SDK for Android、Kotlin Multiplatform）は、Android 版を決めるときに調べ直す |

## 出典一覧

Apple（開発者向けドキュメントとリリースノートは JSON で取得。2026-09-24）
- Software Releases: https://developer.apple.com/news/releases/
- Upcoming Requirements: https://developer.apple.com/news/upcoming-requirements/
- iOS & iPadOS 27 Release Notes: https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
- Xcode 27 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes
- Xcode 26.3 Release Notes: https://developer.apple.com/documentation/xcode-release-notes/xcode-26_3-release-notes
- Giving external agents access to Xcode: https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode
- Updating your Xcode project configuration file format: https://developer.apple.com/documentation/xcode/updating-your-xcode-project-configuration-file-format
- Adopting Liquid Glass: https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- glassEffect(_:in:): https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
- enableBackgroundDelivery(for:frequency:withCompletion:): https://developer.apple.com/documentation/healthkit/hkhealthstore/enablebackgrounddelivery(for:frequency:withcompletion:)
- HKAnchoredObjectQuery: https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery
- HKCorrelationTypeIdentifier.food: https://developer.apple.com/documentation/healthkit/hkcorrelationtypeidentifier/food
- AVCam: https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app
- AVCaptureVideoPreviewLayer: https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer
- PhotosPicker: https://developer.apple.com/documentation/photosui/photospicker
- PhotosPickerItem.itemIdentifier: https://developer.apple.com/documentation/photosui/photospickeritem/itemidentifier
- accessibilityReduceMotion: https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion
- scrollTargetBehavior(_:): https://developer.apple.com/documentation/swiftui/view/scrolltargetbehavior(_:)
- Develop in Swift Tutorials: https://developer.apple.com/tutorials/develop-in-swift
- SwiftUI Tutorials: https://developer.apple.com/tutorials/swiftui
- App Review Guidelines（2.5.2）: https://developer.apple.com/app-store/review/guidelines/
- Apple Developer Program License Agreement（3.3.1(B)）: https://developer.apple.com/support/terms/apple-developer-program-license-agreement/

Swift.org
- Getting Started with the Swift SDK for Android: https://www.swift.org/documentation/articles/swift-sdk-for-android-getting-started.html

React Native
- React Native 0.82: https://reactnative.dev/blog/2025/10/08/react-native-0.82
- React Native 0.84: https://reactnative.dev/blog/2026/02/11/react-native-0.84
- React Native 0.87: https://reactnative.dev/blog/2026/08/11/react-native-0.87
- Set Up Your Environment: https://reactnative.dev/docs/environment-setup
- AccessibilityInfo: https://reactnative.dev/docs/accessibilityinfo
- Accessibility: https://reactnative.dev/docs/accessibility
- Alert: https://reactnative.dev/docs/alert

Expo
- SDK のバージョン表: https://docs.expo.dev/versions/latest/
- SDK 54: https://expo.dev/changelog/sdk-54
- SDK 57: https://expo.dev/changelog/sdk-57
- SDK 58 Beta: https://expo.dev/changelog/sdk-58-beta
- Expo Go and the App Store in May 2026: https://expo.dev/changelog/expo-go-and-app-store-may-2026
- Expo MCP Server on the Free plan: https://expo.dev/changelog/the-expo-mcp-server-is-now-available-on-the-free-plan
- Connect Expo in the Claude desktop app: https://expo.dev/changelog/connect-expo-in-claude
- Camera: https://docs.expo.dev/versions/latest/sdk/camera/
- ImagePicker: https://docs.expo.dev/versions/latest/sdk/imagepicker/
- AppleAuthentication: https://docs.expo.dev/versions/latest/sdk/apple-authentication/
- Notifications: https://docs.expo.dev/versions/latest/sdk/notifications/
- GlassEffect: https://docs.expo.dev/versions/latest/sdk/glass-effect/
- Expo UI（SwiftUI）: https://docs.expo.dev/guides/expo-ui-swift-ui/
- Expo Router Stack: https://docs.expo.dev/router/advanced/stack/
- EAS Update: https://docs.expo.dev/eas-update/introduction/ 、https://docs.expo.dev/eas-update/faq/
- EAS Build のインフラ: https://docs.expo.dev/build-reference/infrastructure/
- 料金: https://expo.dev/pricing

第三者ライブラリ（GitHub を clone して読んだ。npm で最新版と公開日を確認）
- @kingstinct/react-native-healthkit 16.0.0: https://github.com/kingstinct/react-native-healthkit
- react-native-health 1.19.0: https://github.com/agencyenterprise/react-native-health
- react-native-vision-camera 5.2.3: https://github.com/mrousavy/react-native-vision-camera
- react-native-screens 4.28.0: https://github.com/software-mansion/react-native-screens
