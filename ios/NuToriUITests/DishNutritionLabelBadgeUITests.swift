import XCTest

/// 料理の画面の材料の行のうち、栄養の出どころが栄養成分表示の材料にだけ「表示」の印が出る。
/// 条件は、サインイン済みで写真を1枚選べ、API が栄養成分表示の材料を持つ料理の場面（写真を送ると、次に取りに行ったときにカレーライスの推定が届く。ご飯は成分表、レトルトカレーは栄養成分表示）のとき
@MainActor
final class DishNutritionLabelBadgeUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "meal-nutrition-label", healthLatestKilograms: nil,
            pickedPhotos: UITestPickedPhotos(source: .solidColors(count: 1)),
            now: .morningBeforeNotice,
            timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
    }

    func test_料理の画面で栄養成分表示の材料の行にだけ表示の印が出ること() {
        app.buttons["composer-photos"].tap()
        let card = app.buttons["meal-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        XCTAssertTrue(waitUntil(card, matches: "label CONTAINS %@", "カレーライス"))
        // タイムラインのカードには、印が増えない。食事の画面から戻ると書く欄のキーボードがカードを覆うことがあるので、潜る前に見る
        XCTAssertFalse(app.staticTexts["nutrition-label-badge"].exists)
        card.tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))
        let curry = app.mealDish(named: "カレーライス")
        XCTAssertTrue(curry.waitForExistence(timeout: 5))
        // 食事の画面の料理の行には、印が増えない
        XCTAssertFalse(app.staticTexts["nutrition-label-badge"].exists)
        attachScreenshot(of: app, named: "栄養成分表示の材料を持つ料理の食事の画面")

        curry.tap()
        XCTAssertTrue(app.navigationBars["カレーライス"].waitForExistence(timeout: 5))
        let retortCurry = app.staticTexts["レトルトカレー"]
        let rice = app.staticTexts["ご飯"]
        XCTAssertTrue(retortCurry.waitForExistence(timeout: 5))
        XCTAssertTrue(rice.exists)
        // 印は1つだけで、レトルトカレーの行（名前と同じ高さ）に出る
        let badges = app.staticTexts.matching(identifier: "nutrition-label-badge")
        XCTAssertEqual(badges.count, 1)
        let badge = badges.firstMatch
        XCTAssertEqual(badge.label, "表示")
        XCTAssertEqual(badge.frame.midY, retortCurry.frame.midY, accuracy: 4)
        XCTAssertGreaterThan(abs(badge.frame.midY - rice.frame.midY), 4)
        attachScreenshot(of: app, named: "表示の印のある料理の画面")
    }
}
