# ios

nu-tori の iPhone アプリ（SwiftUI、ADR-0004）。

## 構成

- 画面を持たないロジックは、ローカルの Swift パッケージ `NuToriCore/` に置き、SwiftUI・UIKit・HealthKit・SwiftData を import しない。下の「端末で行うもの」の計算と判定と、送り待ちの判断がここに入る。Linux のエージェントと CI でも型検査とテストを回すため
- ファイルを足すとき、`project.pbxproj` は直さない（フォルダの同期で拾われる）
- 型検査の厳しさの設定は `NuToriCore/Package.swift` と `project.pbxproj` の2か所にあるので、そろえる
- Bundle ID は変えない。App Store Connect に上げたあとは変えられず、サーバーの Sign in with Apple の `aud` もこの値を見る

## 端末で行うもの

ルートの `AGENTS.md` の「リポジトリ全体の決定」の基準に当たるものだけを端末で行う。今の一覧:

- 記録をまとめて見せるための計算: 材料の量からの栄養、材料から料理・食事への栄養の合計、料理の量を直したときの材料の量の比例、1日の丸・日のまとめの合計、週の振り返りの平均、習慣トラッカー、日と週の区切り
- 記録忘れの判定: ローカル通知の予約と取り消し、記録忘れの知らせ
- 入力の検証: 受け付ける値の範囲
- 選んだ写真のまとめ方: 複数枚を一度に選んだとき、撮影時刻が近いものを1つの食事にまとめる（基準1）

材料の量の比例は端末だけが持ち、比例させた結果をサーバーに送る。目標と目安の計算、いつもの時刻の学習、写真と文章からの推定はサーバーで行い、端末は結果（材料の栄養の値まで）を受け取る。

## 対応する iOS

- 最低対応版を変えるときは、`project.pbxproj` と `NuToriCore/Package.swift` の2か所をそろえる（今の版の理由は「[iOS の最低対応版を 26 に下げる](https://github.com/gn-t-k/nu-tori/issues/86)」の解決コメント）
- SwiftData の保存は、メインのコンテキストでだけ行う。バックグラウンドの ModelActor で保存すると、iOS 26 では `@Query` がデッドロックすることがある
- iOS 27 からの API（`ResultsObserver`、`HistoryObserver` など）の代わりに書いたところには、置き換え先の API を1行のコメントで残す。最低対応版を上げたときに探して置き換えるため

## 身体データ

- 目標の設定の途中で手で入れた身体データは、端末の中だけに持ち、目標が決まったら捨てる

## API

- クライアントは、`server/` が書き出した OpenAPI の文書から生成する

## 作業の分け方

チケットと PR は、UI 以外（ロジックのパッケージ、API クライアント、テスト）と、UI の確認（画面、シミュレータ、実機）に分ける。Mac を閉じているあいだも、前者はクラウドのエージェント（Linux）で進めるため。UI の確認は Mac の上のエージェントで行い、開発者が外にいて Mac を開けて置く日は、Mac で `claude remote-control --spawn worktree` を動かし、スマホから頼む。

## 確かめる

`scripts/check` を通したうえで、変えたものを動かして確かめる。

- Mac では、MobileBuildMCP で、変えたら `test_sim` を回し、関係する画面を開いて `screenshot` で確かめる。`test_sim` が行き先を見つけられずに失敗したら、開発者に `xcodebuild -downloadPlatform iOS`（数 GB）を頼む。computer use は、これらで確かめられないときにだけ使う
- SwiftUI プレビュー（`RenderPreview`）とビルドログ（`GetBuildLog`）は、MobileBuildMCP の `xcode_ide_call_tool` で Xcode の道具を呼ぶ。Xcode の画面は開かなくてよい。先に `XcodeOpenWorkspace` で、作業しているワークツリーの `ios/NuTori.xcodeproj` を開く。Xcode はフォルダごとに承認を求めるので、ワークツリーごとに1回、開発者に Mac で承認してもらう。Remote Control のセッションでは開発者が承認を押せないので、Xcode の道具を使わず `screenshot` で確かめる
- Xcode の MCP（`xcrun mcpbridge`）は、各ツールの MCP の設定に直接置かず、MobileBuildMCP の中継で呼ぶ
- Linux では、アプリのビルドと UI テストを CI の `ios-app` に任せる。失敗したら、`.github/workflows/check.yml` の `ios-app` が上げる成果物（失敗の要約とスクリーンショット）を `gh api repos/gn-t-k/nu-tori/actions/artifacts/<ID>/zip` で落として読む
- 整形の正は、`.swift-version` の版の Linux の swift-format にする。Xcode に同梱の版と違うことがあるので、macOS では整形を確かめない
- ロジックのパッケージのテストを macOS でも回すのは、Linux と macOS で Foundation の振る舞いが違うことがあるため

## 版を上げる

Dependabot が上げない次のものは、月に一度、開発者に頼まれたときと Dependabot の PR を片付けるときに、最新を確かめて（`git ls-remote --tags`）手で上げる。

- Swift: `ios/.swift-version` と、CI の `ios` のジョブの `container:` のタグと digest をそろえて上げる。swift-format が Swift に付いてくるので、整形だけの差分は別のコミットにする
- SwiftLint: `scripts/check` の版と、配布物ごとの SHA-256
- sentry-cli: `ci_scripts/ci_post_xcodebuild.sh` の版と SHA-256（Sentry のリリースの登録簿 `release-registry.services.sentry.io/apps/sentry-cli/<版>` の `sentry-cli-Darwin-universal`）
- Xcode のプロジェクトの Swift Package の依存

Swift のパッケージの依存を足したら、Dependabot の `swift` を足すかを決める。Dependabot の Swift は 6.3.1（2026-09-26 時点、`docs/research/agent-tools-setup.md`）で、`swift-tools-version: 6.4` の manifest を読めないおそれがある。

## 配布

- main にマージするたびに、Xcode Cloud がビルドして TestFlight の内部テストに配る。署名とビルド番号は Apple 側に任せ、証明書を GitHub に置かない
- Xcode Cloud のワークフローは「main から内部テスト」の1つ。枠（月 25 時間）に収めるため、main の `ios/` が変わったとき（と手で始めたとき）だけ動かし、アクションは Archive（Distribution Preparation は App Store Connect。外部テストと App Store に出せるのはこれだけ）だけにする。配る先は内部テストのグループ「初回リリーステストユーザーグループ」。設定は Xcode の Report navigator の Cloud のタブで直す
- Xcode Cloud の秘密の値は、ワークフローの Environment に Secret で置く。アーカイブのあとに `ci_scripts/ci_post_xcodebuild.sh` が dSYM を Sentry に上げ、`SENTRY_AUTH_TOKEN`（Sentry の組織のトークン）が無ければ飛ばす

## 実機の確認

エージェントには実機を操作する道が無いので、人が確かめる。

- 確かめるのは、ヘルスケア、カメラ、通知、写真の読み込みに触れた PR をマージしたあとと、外部テストに出す前。エージェントは、該当する PR の本文に「実機の確認が要る」と書き、確かめる項目を並べる
- ヘルスケアは、「[ヘルスケアの読み書きの対応表](https://github.com/gn-t-k/nu-tori/issues/27)」の追記の「実機で確かめるまで見込みのもの」に加えて、他のアプリの当日の体重で通知が取り消されることを確かめる。nu-tori を閉じてヘルスケアアプリで体重を手入力すると、その日の体重の通知が取り消され、開くと体重のボタンが目立たない。MacroFactor で入れても同じになる
