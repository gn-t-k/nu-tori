# Swift での当てはめ

`docs/agents/coding-style.md` と `docs/agents/testing.md` の好みを、Swift・SwiftUI で書くときの形。コンポーネントは SwiftUI の View にあたる。

## コーディング

### 型検査の前提

- 型検査はいちばん厳しくする。Swift 6 の言語モードに、まだ既定でない upcoming features をすべて足し、警告（非推奨を含む）はエラーにする。このファイルの話はそれを前提にする
- 抑止（`@diagnose`、`// swiftlint:disable`、`// swift-format-ignore`）を足すときは、PR に理由を書く。非推奨の警告を抑えてよいのは、SDK を上げてすぐ直せないときだけ

### コードを説明する情報

- `///` のドキュメントコメントも、`docs/agents/coding-style.md` の「コードを説明する情報」のコメントの決まりに入る

### ファイルと公開するもの

- 公開するものは、トップレベルの private でない型か関数で数える。`private`・`fileprivate` の型と `#Preview` は数えない
- 例: `WeightTrend.swift` → `struct WeightTrend`、`TimelineView.swift` → `struct TimelineView`
- 型にだけ意味を持つ整形・判定は、同じファイルの extension に置く

### ファイルの中はトップダウン

- View の中は `body` を上に、private な計算プロパティや下位の View を下に置く

### 定数は最小のスコープに置く

- 型やモジュールのスコープの定数は、型の `static` かファイルのスコープに置く

### 状態は論理状態の数で型を作る

- タグ付きユニオンは enum で書き、値はその値が意味を持つ case の associated value に持たせる

```swift
enum WeightRecordsState {
    case loading
    case failed(any Error)
    case loaded([WeightRecord])
}
```

### 関数は処理の流れで分ける

- 自分たちの enum の switch には `default` を置かない。case を足したときの漏れがコンパイルエラーになる

### 値が無いことを許すのは、必要な事情があるときだけ

- 常にある枠で、中身が空になり得るものは `let caption: String?` にして、呼び出し側に nil を明示させる。`var` の optional は memberwise init に `= nil` が付き、渡し忘れが型で見えなくなる。引数の `= nil` も同じ

### キャストのいらない形を探す

- キャストは、確かめて変換する `as?` と `as!` を指す。`as!` は使わない。`as?` も、キャストの要らない形を探す対象に入る。見直す候補に protocol と enum を加える

### 新しい技術を選ぶ

- 例: `ObservableObject` に対する `@Observable`、XCTest に対する Swift Testing（Swift Testing で書けない UI テストは XCUITest のまま）、完了ハンドラに対する async/await

### 依存パッケージ

- Swift Package の依存は `exact:`（Xcode では「Exact Version」）で固定する。`from:` や「Up to Next Major」の範囲指定にしない
- 最新の版は `git ls-remote --tags <パッケージのリポジトリの URL>` で確かめる

## テスト

### 道具

- UI テスト以外（単体テストと統合テスト）は Swift Testing で書く
- UI テストは XCUITest（XCTestCase）で書き、失敗したときに画面を見られるよう、確かめた画面のスクリーンショットを `XCTAttachment` で残す

### Swift Testing の構造

- まとまりは `@Suite`、テストは `@Test` で書き、名前は表示名の文字列に書く
- 「各テストの前の準備」は、条件の `@Suite` の `init()` で行う。Swift Testing は `@Test` ごとに Suite を作り直すので、`init()` が各テストの前に走る
- パラメータ化テストは `@Test(arguments:)` のこと

```swift
@Suite("体重の傾向の計算")
struct ComputeWeightTrendTests {
    @Suite("体重記録が1件もないとき")
    struct NoRecords {
        let records: [WeightRecord]

        init() {
            records = []
        }

        @Test("傾向が空になること")
        func trendIsEmpty() {
            #expect(computeWeightTrend(from: records).isEmpty)
        }
    }
}
```

### XCUITest の構造

XCTestCase はまとまりを入れ子にできず、クラス名が識別子になるので、`docs/agents/testing.md` の「機能 → シナリオの分類の入れ子」と、まとまりの「日本語の名前」は、次の形に置き換える。

- 条件ごとに1つのクラスを1つのファイルに置き、クラス名とファイル名に経路と条件を書く（`RecordWeightWithoutGoalUITests.swift`）
- 準備（アプリの起動と、条件の状態にするまでの操作）は `setUp` で行う
- メソッドは `test_〜こと` の日本語の名前にする

### 依存の差し替え

- 差し替え用の型は `{依存の名前}Mock`（`WeightRecordStore` → `WeightRecordStoreMock`）にし、テストターゲットの `{依存の名前}Mock.swift` に置く
- 呼び出しを記録する差し替えは class にする。struct は渡した先で写されるので、テスト対象が記録してもテストの手元に残らない
- 成功と失敗の作り方は、その型の static 関数 `.ok(...)` と `.error(_:)` にする
- 引数を確かめるテストは、差し替え用の型を Suite のプロパティに持って `@Test` で参照する
- 複数のテストターゲットが使う差し替えは、`NuToriCore/Sources/NuToriTestSupport/`（テスト用のターゲット。アプリのターゲットは依存しない）に1つずつ置く。今は API のトランスポートの差し替え（`ClientTransportMock`）、送り待ちの箱の差し替え（`SyncBoxMock`。キャッシュは `RecordCacheMock`。登録簿の1行は `WeightRecordKindMock`・`AccountSettingsRecordKindMock`、登録簿は `RecordKindRegistry.ok(extra:)`）、送り待ちを送った本文を読む型（`SentWritesBody`）。同じ差し替えを、テストターゲットごとに作らない
- `SentWritesBody` は、知らない種類の書き込みを読むと投げて、テストを落とす。書き込みの種類を足したら、`SentWritesBody.Write` に足す
- UI テストのための差し替え（API、サインイン済みの状態など）は、UI テストがアプリと別のプロセスで動くので、テストターゲットではなくアプリのターゲットに `#if DEBUG` で囲んで置き、Release のビルドに入れない。UI テストは起動の値（`launchEnvironment`）で切り替える

### ファイルの置き場所

- Swift Testing のテストは、テストターゲットの中で実装と同じディレクトリ構成にし、`{テスト対象の名前}Tests.swift` にする（`computeWeightTrend` → `ComputeWeightTrendTests.swift`）

### 日時は実行環境に左右されない形で確かめる

- `Date.formatted()` や `FormatStyle` は、指定しなければ実行環境のタイムゾーンとロケールで整形する
- Swift Testing のテストは `TEST_RUNNER_TZ=UTC xcodebuild test -testLanguage en -testRegion US ...` のように変えて確かめる
- UI テストで起動するアプリには `TEST_RUNNER_TZ` が届かないので、`XCUIApplication` の `launchEnvironment` で `TZ` を渡す
