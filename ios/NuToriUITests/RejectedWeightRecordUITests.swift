import XCTest

@MainActor
final class RejectedWeightRecordUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", api: "previous-day-push-rejected")
    }

    func test_受け付けなかった記録の位置に1行出て未記録の見た目に戻ること() {
        XCTAssertTrue(app.staticText(containing: "72.6 kg").waitForExistence(timeout: 5))
        app.recordWeightTwoTenthsLower()
        XCTAssertTrue(app.staticTexts["rejected-weight-line"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight-unrecorded"].exists)
        XCTAssertTrue(app.staticText(containing: "72.6 kg").exists)
        attachScreenshot(of: app, named: "受け付けなかった体重の1行")
    }
}
