import XCTest

@MainActor
final class RecordWeightOfflineUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "previous-day-push-offline", healthLatestKilograms: nil,
            timeZone: nil)
    }

    func test_電波が無くても記録した体重がタイムラインに出ること() {
        XCTAssertTrue(app.staticText(containing: "72.6 kg").waitForExistence(timeout: 5))
        app.recordWeightTwoTenthsLower()
        XCTAssertTrue(app.staticText(containing: "72.4 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight"].exists)
        XCTAssertFalse(app.staticTexts["rejected-weight-line"].exists)
        // まだ届いていない記録は、読み上げの最後に「送信待ち」を添える。届いている昨日の記録には添えない
        XCTAssertTrue(
            undeliveredWeightRow(labelContaining: "72.4 kg").waitForExistence(timeout: 5))
        XCTAssertTrue(deliveredWeightRow(labelContaining: "72.6 kg").exists)
        attachScreenshot(of: app, named: "電波が無いときに記録した体重")
    }

    /// 読み上げの最後に「送信待ち」を添えた体重の行
    private func undeliveredWeightRow(labelContaining text: String) -> XCUIElement {
        app.buttons.matching(identifier: "weight-row")
            .matching(
                NSPredicate(format: "label CONTAINS %@ AND label ENDSWITH %@", text, "送信待ち")
            )
            .firstMatch
    }

    /// 読み上げの最後に「送信待ち」を添えていない体重の行
    private func deliveredWeightRow(labelContaining text: String) -> XCUIElement {
        app.buttons.matching(identifier: "weight-row")
            .matching(
                NSPredicate(
                    format: "label CONTAINS %@ AND NOT (label ENDSWITH %@)", text, "送信待ち")
            )
            .firstMatch
    }
}
