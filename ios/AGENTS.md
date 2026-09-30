# ios

nu-tori の iPhone アプリ（SwiftUI、ADR-0004）。

## 構成

- 画面を持たないロジックは、ローカルの Swift パッケージ `NuToriCore/` に置き、SwiftUI・UIKit・HealthKit・SwiftData を import しない。下の「端末で行うもの」の計算と判定と、送り待ちの判断がここに入る。Linux のエージェントと CI でも型検査とテストを回すため
- 記録の種類（今は体重記録とアカウントの設定）ごとに、フォルダを切る。`NuToriCore/Sources/NuToriCore/`・`NuToriCore/Sources/NuToriAPI/`・`NuTori/`（アプリのターゲット）のそれぞれに `WeightRecord/`、`AccountSettings/` を置き、その種類だけにかかる型・判断・SwiftData のモデル・画面を入れる。テストのターゲットも同じフォルダ名でそろえる。同期の共通のもの（同期の働き、同期の置き場の型、送り待ち）は `Sync/`、タイムラインは `Timeline/` に残す。機能を第一の軸にする切り方を採らなかった理由は「[コードの置き方を、機能ごとに縦に切るかを決める](https://github.com/gn-t-k/nu-tori/issues/153)」の解決コメント
- 端末の SwiftData は2つの置き場に分ける（[ADR-0022](../docs/adr/0022-device-cache-and-pending-writes-in-separate-stores.md)）。`SwiftDataSyncStore` が両方を持つ
  - キャッシュ（`CacheStore`）: 記録、アカウントの設定、同期の状態（通し番号など）。サーバーの写しなので移行を持たず、形が合わず開けないときは置き場ごと消して全部取り直す（取り終えるまでタイムラインは初回の取得と同じ読み込み中）。モデルは `CacheStoreSchema` に並べる
  - 送り待ち（`PendingStore`）: 送り待ちとヘルスケアの同期の進み具合。`PendingStoreMigrationPlan` の版つきのスキーマで移行し、版ごとのモデルの写し（`PendingStoreSchemaV1`・`PendingStoreSchemaV2` の中）を固める。形を変えるときは、写しを固めたまま次の版を足す。送り待ちは「種類の名前＋中身」（`PendingEntry`）で持つので、種類を足しても形は変わらない
  - 送り待ちの箱（`SyncBox`）、記録の種類（`RecordKind`。`synced` に NuToriCore の種類を1つ持ち、キャッシュへの `apply`・`erase` だけを書く）、登録簿（`AppRecordKinds.registry`）が同期の入口。それぞれの役割と種類の足し方は `docs/agents/sync.md`。メモリの箱は `NuToriTestSupport` の `SyncBoxMock`（キャッシュが `RecordCacheMock` のものを、テストが `SyncBoxMock.ok(...)`・`.error(...)` で作る）
  - 種類の名前: NuToriCore の `RecordKindName`（enum。rawValue は送り待ちに保存するハイフンの書き方。`weight-record`、`account-settings`）で、送り待ち・変更・登録簿・読める種類を渡す。足すときは case を足す。SwiftData のモデルは文字列のまま持ち、読み書きの口で `RecordKindName` に変える（読めない名前の送り待ちは開くときに捨てて `storeRecovery` に残す）。サーバーの列挙（`server/openapi.json` の `RecordKindName`。snake_case）との対応は `RecordKindName.serverName` の switch だけに書き、`ServerRecordKindNames.names` と突き合わせる（`AppRecordKindsTests`）。保存した名前（rawValue）を変えると、送り待ちの置き場の移行が要る
  - 保存の順: 記録を作る・直すときは、送り待ちを先に保存し、キャッシュをそのあとに保存する。全消去は、送り待ちを1つの保存で空にしてから、キャッシュを空にする
  - 置き場を分ける前の1つの置き場（`RecordStore`）は、更新して最初に開いたときに、送り待ちとヘルスケアの同期の進み具合を送り待ちの置き場へ移して消す（`LegacyRecordStore`）。開けない形のときは送り待ちを捨て、`HandledFailure.storeRecovery` として Sentry に送る
- ファイルを足すとき、`project.pbxproj` は直さない（フォルダの同期で拾われる）
- 型検査の厳しさの設定は `NuToriCore/Package.swift`、`SharedRulesGenerator/Package.swift`、`project.pbxproj` の3か所にあるので、そろえる
- Bundle ID は変えない。App Store Connect に上げたあとは変えられず、サーバーの Sign in with Apple の `aud` もこの値を見る

## 端末で行うもの

ルートの `AGENTS.md` の「リポジトリ全体の決定」の基準に当たるものだけを端末で行う。今の一覧:

- 記録をまとめて見せるための計算: 材料の量からの栄養、材料から料理・食事への栄養の合計、料理の量を直したときの材料の量の比例、1日の丸・日のまとめの合計、週の振り返りの平均、習慣トラッカー、日と週の区切り、体重の日の代表値
- 記録忘れの判定: ローカル通知の予約と取り消し、記録忘れの知らせ
- 入力の検証: 受け付ける値の範囲、体重の打ち間違いの判定
- 観測を始めてよいかの判定: PostHog を始めてよいか（利用状況を送るがオンで、初回の取得を終えた）。オフへの切り替えが電波が無くてもその場で効くため
- 選んだ写真のまとめ方: 複数枚を一度に選んだとき、撮影時刻が近いものを1つの食事にまとめる（基準1）

材料の量の比例は端末だけが持ち、比例させた結果をサーバーに送る。目標と目安の計算、いつもの時刻の学習、写真と文章からの推定はサーバーで行い、端末は結果（材料の栄養の値まで）を受け取る。

## 対応する iOS

- 最低対応版を変えるときは、`project.pbxproj` と `NuToriCore/Package.swift` の2か所をそろえる（今の版の理由は「[iOS の最低対応版を 26 に下げる](https://github.com/gn-t-k/nu-tori/issues/86)」の解決コメント）
- SwiftData の保存は、メインのコンテキストでだけ行う。バックグラウンドの ModelActor で保存すると、iOS 26 では `@Query` がデッドロックすることがある
- iOS 27 からの API（`ResultsObserver`、`HistoryObserver` など）の代わりに書いたところには、置き換え先の API を1行のコメントで残す。最低対応版を上げたときに探して置き換えるため

## 身体データ

- 目標の設定の途中で手で入れた身体データは、端末の中だけに持ち、目標が決まったら捨てる

## API

- クライアントは、`server/openapi.json` から swift-openapi-generator で生成し、`NuToriCore/Sources/NuToriAPI/Generated/` にコミットする。`server/openapi.json` が変わったら `scripts/check ios --fix` で生成し直す（`scripts/check ios` が最新かを確かめる）。生成器は `OpenAPIGenerator/` のパッケージで動かし、アプリのビルドには入れない。設定は `OpenAPIGenerator/openapi-generator-config.yaml`
- 生成したコードは `internal` にし、アプリには `NuToriAPIClient` だけを見せる。経路を足したら、`NuToriAPIClient` にメソッドを足し、応答をアプリで扱う形（文書にある状態コードごとの enum）にして返す

## 作業の分け方

チケットと PR を切り分けるときは、`docs/agents/issue-tracker.md` の「iOS のチケットと PR の分け方」を読む。

## 確かめる

`scripts/check` を通したうえで、変えたものを動かして確かめる。Mac で作業するときは `docs/agents/ios-mac.md` を読む。

- Linux で `swift` が無いときは、`scripts/install-swift` で入れる
- Linux では、アプリのビルドを CI の `ios-app` に、UI テストを `ios-ui-test` に任せる。UI テストか画面の経路を変える PR には、`ui-test` のラベルを付けて UI テストを回す。PR の無いブランチでは、`gh workflow run ios-ui-test.yml --ref <ブランチ>` で回す。落ちたら、`.github/workflows/ios-ui-test.yml` が上げる成果物（失敗の要約とスクリーンショット）を `gh api repos/gn-t-k/nu-tori/actions/artifacts/<ID>/zip` で落として読む
- UI テストはサーバーにつながない。API とサインイン済みの状態を差し替える（差し替えの置き場と切り替え方は `docs/agents/languages/swift.md` の「依存の差し替え」）。API とのつなぎは、`NuToriAPI` のテスト（トランスポートの差し替え）とサーバーのテストで確かめる

## 配布と実機の確認

- main の `ios/` が変わるたびに、Xcode Cloud がビルドして TestFlight の内部テストに配る。署名とビルド番号は Apple 側に任せ、証明書を GitHub に置かない
- ヘルスケア、カメラ、通知、写真の読み込みに触れた PR を出すとき、外部テストに出す前、Xcode Cloud の設定か `ci_scripts/` を直すときは、`docs/agents/ios-release.md` を読む
