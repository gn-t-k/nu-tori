import XCTest

@MainActor
final class ImportedHealthWeightAfterPullUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in",
            api: "previous-day",
            healthAuthorization: "not-yet-requested",
            healthLatestKilograms: "68.0"
        )
    }

    func test_初回の取得のあとにヘルスケアの体重がタイムラインに出ること() {
        XCTAssertTrue(app.staticText(containing: "72.6 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticText(containing: "68.0 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["体重計アプリ"].exists)
        attachScreenshot(of: app, named: "初回の取得のあとに取り込んだ体重")
    }
}
