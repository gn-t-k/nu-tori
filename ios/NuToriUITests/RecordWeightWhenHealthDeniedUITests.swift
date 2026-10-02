import XCTest

@MainActor
final class RecordWeightWhenHealthDeniedUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in",
            api: "previous-day",
            healthAuthorization: "not-yet-requested",
            healthLatestKilograms: nil,
            healthWrite: "denied",
            timeZone: nil
        )
    }

    func test_ヘルスケアの書き込みを断っても体重を記録できること() {
        XCTAssertTrue(app.staticText(containing: "72.6 kg").waitForExistence(timeout: 5))
        app.recordWeightTwoTenthsLower()
        XCTAssertTrue(app.staticText(containing: "72.4 kg").waitForExistence(timeout: 5))
        XCTAssertFalse(app.weightEntryRecordButton.exists)
        attachScreenshot(of: app, named: "ヘルスケアを断っても記録した体重")
    }
}
