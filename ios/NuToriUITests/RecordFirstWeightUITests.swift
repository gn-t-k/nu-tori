import XCTest

@MainActor
final class RecordFirstWeightUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "online", healthLatestKilograms: nil, timeZone: nil)
    }

    func test_前回の体重が無くてもシートを開くとキーボードで入れて記録できること() {
        XCTAssertTrue(app.buttons["composer-weight-unrecorded"].waitForExistence(timeout: 5))
        app.buttons["composer-weight-unrecorded"].tap()
        XCTAssertTrue(
            app.otherElements["weight-entry-sheet"].textFields["体重の値"].waitForExistence(
                timeout: 5))
        app.typeSeventyKilograms()
        app.weightEntryRecordButton.tap()
        XCTAssertTrue(app.staticText(containing: "70.0 kg").waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "前回の体重が無いときに記録した体重")
    }
}
