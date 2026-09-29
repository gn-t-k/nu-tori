import XCTest

@MainActor
final class RecordWeightOfflineUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", api: "previous-day-push-offline")
    }

    func test_電波が無くても記録した体重がタイムラインに出ること() {
        XCTAssertTrue(app.staticText(containing: "72.6 kg").waitForExistence(timeout: 5))
        app.recordWeightTwoTenthsLower()
        XCTAssertTrue(app.staticText(containing: "72.4 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight"].exists)
        XCTAssertFalse(app.staticText(containing: "記録できませんでした").exists)
        attachScreenshot(of: app, named: "電波が無いときに記録した体重")
    }
}
