import XCTest

/// 食事を画面に収まらないだけ並べてタイムラインを遡った状態で、「写真」で写真を選ぶ → 足した食事のカードが見える位置（一番下）に戻る。
/// 写真の選択は起動の値で差し替える（選ぶ画面を開かずに1枚選んだことにする）
@MainActor
final class ReturnToTimelineEndAfterPickedPhotosUITests: XCTestCase {
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

    func test_遡ってから写真を選ぶと足した食事のカードが見える位置に戻ること() {
        app.buttons["composer-photos"].tap()

        let added = mealCards.element(boundBy: Self.mealsFillingScreen)
        XCTAssertTrue(added.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntilHittable(added))
        attachScreenshot(of: app, named: "写真を足して一番下に戻ったタイムライン")
    }

    /// カードが画面の高さを超えて並び、遡れるようになる数
    private static let mealsFillingScreen = 5

    private var mealCards: XCUIElementQuery {
        app.buttons.matching(identifier: "meal-card")
    }
}
