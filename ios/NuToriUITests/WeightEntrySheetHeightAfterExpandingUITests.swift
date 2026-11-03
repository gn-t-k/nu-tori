import XCTest

/// large に広げたあとでも、値の欄をキーボードで打ち始めたら体重のシートはキーボードのすぐ上に載る
@MainActor
final class WeightEntrySheetHeightAfterExpandingUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "previous-day", healthLatestKilograms: nil, timeZone: nil)
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        app.buttons["composer-weight"].tap()
        XCTAssertTrue(app.weightEntryPreviousLine.waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitUntilWeightEntrySheetFitsContent())
        app.dragWeightEntryNavigationBar(toY: 0.1)
        XCTAssertTrue(app.waitUntilWeightEntrySheetIsExpanded())
    }

    func test_打ち始めるとシートがキーボードのすぐ上に載ること() {
        app.otherElements["weight-entry-sheet"].buttons["体重"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        XCTAssertTrue(
            app.waitUntilWeightEntrySheetSitsOnKeyboard(below: app.weightEntryPreviousLine))
        attachScreenshot(of: app, named: "広げてから打ち始めた体重のシート")
    }
}
