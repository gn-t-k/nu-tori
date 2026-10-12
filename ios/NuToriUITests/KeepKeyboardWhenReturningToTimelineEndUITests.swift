import XCTest

/// 食事を画面に収まらないだけ並べてタイムラインを遡り、書く欄を押してキーボードを出した状態で、「写真」で写真を選ぶ → 一番下に戻っても、キーボードは出たまま。
/// 写真の選択は起動の値で差し替える（選ぶ画面を開かずに1枚選んだことにする）
///
/// キーボードを下げるのは使う人が動かし始めたときだけと決める規則は NuToriCore の単体テスト（TimelineViewportTests の「一番下についていく」と「過去の不具合の場面」の #450）が見る。
/// ここで見るのは SwiftUI の癖: アプリが動かしたとき（ScrollViewProxy の scrollTo と、足されたカードについていく動き）には、ScrollView が「触っている」の相を知らせないこと
@MainActor
final class KeepKeyboardWhenReturningToTimelineEndUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "meal-estimation", healthLatestKilograms: nil,
            pickedPhotoCount: 1, now: .morningBeforeNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
        for index in 0..<Self.mealsFillingScreen {
            app.buttons["composer-photos"].tap()
            XCTAssertTrue(mealCards.element(boundBy: index).waitForExistence(timeout: 10))
        }
        let newest = mealCards.element(boundBy: Self.mealsFillingScreen - 1)
        XCTAssertTrue(waitUntilHittable(newest))
        app.otherElements["timeline"].swipeDown()
        app.otherElements["timeline"].swipeDown()
        XCTAssertFalse(newest.isHittable)
        app.composerField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "遡ってキーボードを出したタイムライン")
    }

    func test_キーボードを出したまま写真を選ぶと一番下に戻ってもキーボードが残ること() async throws {
        let photos = app.buttons["composer-photos"]
        // 画面の外へ流れたカードは要素の木から外れて数えられないので、足されたのを日の区切りの高さで、一番下に戻ったのを日の区切りの下端で見る
        let today = app.otherElements["day-section-2026-10-05"]
        XCTAssertTrue(today.exists)
        let height = today.frame.height
        XCTAssertGreaterThan(today.frame.maxY, photos.frame.minY)
        photos.tap()

        let added = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                MainActor.assumeIsolated { today.frame.height > height + Self.cardMinHeight }
            }, object: nil)
        XCTAssertEqual(XCTWaiter().wait(for: [added], timeout: 10), .completed)
        let shown = try await waitUntil(today, isAbove: photos)
        attachScreenshot(of: app, named: "キーボードを出したまま一番下に戻ったタイムライン")
        XCTAssertTrue(shown, "足した食事のカードが入力欄の下に隠れている")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
    }

    /// カードが画面の高さを超えて並び、遡れるようになる数
    private static let mealsFillingScreen = 5
    /// 食事のカード1枚ぶんより小さい高さ。推定の結果が届いて伸びる分（数十ポイント）とは見分けられる
    private static let cardMinHeight: CGFloat = 200

    private var mealCards: XCUIElementQuery {
        app.buttons.matching(identifier: "meal-card")
    }
}
