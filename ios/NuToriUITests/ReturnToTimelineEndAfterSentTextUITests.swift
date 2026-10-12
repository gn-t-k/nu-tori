import XCTest

/// 食事を画面に収まらないだけ並べてタイムラインを遡った状態で、文章を送る → タイムラインの一番下に戻る。
/// 写真の選択は起動の値で差し替える（選ぶ画面を開かずに1枚選んだことにする）
@MainActor
final class ReturnToTimelineEndAfterSentTextUITests: XCTestCase {
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
        attachScreenshot(of: app, named: "遡ったタイムライン")
    }

    func test_遡ってから文章を送るとタイムラインの一番下に戻ること() {
        app.composerField.tap()
        app.composerField.typeText("散歩した")
        app.buttons["composer-send"].tap()

        // 時計を止めているので、吹き出しは同じ時刻の食事のカードより上に並ぶ。一番下に戻ったことは、いちばん下のカードで確かめる
        let newest = mealCards.element(boundBy: Self.mealsFillingScreen - 1)
        let returned = waitUntilHittable(newest)
        attachScreenshot(of: app, named: "文章を送って一番下に戻ったタイムライン")
        XCTAssertTrue(returned, "いちばん下の食事のカードが見える位置に戻っていない")
    }

    /// カードが画面の高さを超えて並び、遡れるようになる数
    private static let mealsFillingScreen = 5

    private var mealCards: XCUIElementQuery {
        app.buttons.matching(identifier: "meal-card")
    }
}
