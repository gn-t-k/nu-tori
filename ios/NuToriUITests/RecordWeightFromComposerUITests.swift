import XCTest

@MainActor
final class RecordWeightFromComposerUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", api: "previous-day")
    }

    func test_入力欄から体重を記録するとタイムラインに出て未記録の見た目が戻ること() {
        XCTAssertTrue(app.staticText(containing: "72.6 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight-unrecorded"].exists)
        app.recordWeightTwoTenthsLower()
        XCTAssertTrue(app.staticText(containing: "72.4 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight"].exists)
        XCTAssertFalse(app.buttons["記録"].exists)
        XCTAssertFalse(app.staticText(containing: "記録できませんでした").exists)
        attachScreenshot(of: app, named: "入力欄から記録した体重")
    }
}
