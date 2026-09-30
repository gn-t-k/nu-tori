import XCTest

@MainActor
final class CorrectWeightRejectedUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "weight-screen-push-rejected", healthLatestKilograms: nil,
            timeZone: nil)
    }

    func test_直す書き込みを受け付けなかったとき記録の下に1行出てサーバーの値に戻ること() {
        let row = app.buttons["weight-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["体重"].waitForExistence(timeout: 5))
        app.buttons["直す"].tap()
        XCTAssertTrue(app.textFields["体重の値"].waitForExistence(timeout: 5))
        app.typeSeventyKilograms()
        app.buttons["完了"].tap()
        app.navigationBars["体重"].buttons.element(boundBy: 0).tap()

        let line = app.staticTexts["rejected-weight-line"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.contains("70.0 kg に直せませんでした"))
        XCTAssertTrue(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", "72.4 kg")
            ).firstMatch.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(line.frame.minY, row.frame.maxY)
        attachScreenshot(of: app, named: "直せなかった体重の1行")
    }
}
