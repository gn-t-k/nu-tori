import XCTest

@MainActor
final class TimelineWeightRecordsUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", api: "weight-records")
    }

    func test_取りに行った体重がタイムラインに並ぶこと() {
        XCTAssertTrue(app.staticText(containing: "72.4 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticText(containing: "71.8 kg").exists)
        XCTAssertTrue(app.staticTexts["Withings"].exists)
        XCTAssertTrue(app.staticText(containing: "から記録しています").exists)
        XCTAssertTrue(app.buttons["アカウント"].exists)
        XCTAssertFalse(app.staticTexts["記録を読み込んでいます…"].exists)
        attachScreenshot(of: app, named: "取りに行った体重が並んだタイムライン")
    }
}
