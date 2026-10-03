import XCTest

/// 縦長の写真の食事カードは、写真を横長の枠に切り抜いて見せる。
/// 枠からはみ出した写真が、すぐ上の体重の行を押したのを横取りしないこと
@MainActor
final class OpenWeightAboveMealPhotoUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "meal-estimation", healthLatestKilograms: "72.6",
            pickedPhotoCount: 1, timeZone: nil)
        XCTAssertTrue(app.buttons["composer-photos"].waitForExistence(timeout: 5))
        app.recordWeightTwoTenthsLower()
        XCTAssertTrue(weightRow.waitForExistence(timeout: 5))
        app.buttons["composer-photos"].tap()
        XCTAssertTrue(app.buttons["meal-card"].waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "体重の行のすぐ下の食事カード")
    }

    func test_食事カードのすぐ上の体重の行を押すと体重の画面が開くこと() {
        weightRow.tap()

        XCTAssertTrue(app.navigationBars["体重"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["食事"].exists)
        attachScreenshot(of: app, named: "食事カードの上の体重の行から開いた体重の画面")
    }

    /// ヘルスケアから取り込んだ 72.6 kg の行もあるので、食事のすぐ上に並ぶ、記録した行を選ぶ
    private var weightRow: XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "weight-row", "72.4 kg")
        ).firstMatch
    }
}
