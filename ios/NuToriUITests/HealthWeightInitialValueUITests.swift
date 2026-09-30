import XCTest

@MainActor
final class HealthWeightInitialValueUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in",
            healthAuthorization: "not-yet-requested",
            healthLatestKilograms: "71.25"
        )
    }

    func test_初めて体重を押すとヘルスケアの最新の値が初期値になること() {
        XCTAssertTrue(app.buttons["composer-weight-unrecorded"].waitForExistence(timeout: 5))
        app.buttons["体重"].tap()
        XCTAssertTrue(app.staticTexts["71.3"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["記録"].exists)
        attachScreenshot(of: app, named: "ヘルスケアの値を初期値にしたシート")
    }
}
