import XCTest

@MainActor
final class CorrectWeightFromWeightScreenUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", api: "weight-screen", timeZone: nil)
    }

    func test_体重の画面で直すとタイムラインの値が変わること() {
        XCTAssertTrue(app.buttons["weight-row"].waitForExistence(timeout: 5))
        app.buttons["weight-row"].tap()
        XCTAssertTrue(app.navigationBars["体重"].waitForExistence(timeout: 5))
        app.buttons["直す"].tap()
        let field = app.textFields["体重の値"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        typeSeventy()
        app.buttons["完了"].tap()
        XCTAssertTrue(app.staticTexts["70.0"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "体重の画面で直した値")
        app.navigationBars["体重"].buttons.element(boundBy: 0).tap()
        let updated = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "70.0 kg")
        ).firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS %@", "72.4 kg")
            ).firstMatch.exists)
        attachScreenshot(of: app, named: "体重の画面で直したあとのタイムライン")
    }

    private func typeSeventy() {
        app.keys["7"].tap()
        app.keys["0"].tap()
        let decimal = app.keys["."]
        if decimal.exists {
            decimal.tap()
        } else {
            app.keys[","].tap()
        }
        app.keys["0"].tap()
    }
}
