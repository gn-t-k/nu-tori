import XCTest

/// 前回の体重があれば、体重のシートは中身の高さで開き、値の欄をキーボードで打ち始めたら広がる
@MainActor
final class WeightEntrySheetHeightWithPreviousWeightUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "previous-day", healthLatestKilograms: nil, timeZone: nil)
        XCTAssertTrue(app.buttons["composer-weight-unrecorded"].waitForExistence(timeout: 5))
        app.buttons["composer-weight-unrecorded"].tap()
        XCTAssertTrue(app.weightEntryPreviousLine.waitForExistence(timeout: 5))
    }

    func test_中身の下に大きな空きを残さずに開くこと() {
        XCTAssertTrue(app.waitUntilWeightEntrySheetFitsContent())
        attachScreenshot(of: app, named: "中身の高さで開いた体重のシート")
    }

    func test_値の欄を押して打ち始めると広がり値の欄がキーボードに隠れないこと() {
        app.otherElements["weight-entry-sheet"].buttons["体重"].tap()
        let field = app.otherElements["weight-entry-sheet"].textFields["体重の値"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        XCTAssertTrue(app.waitUntilWeightEntrySheetIsExpanded())
        XCTAssertLessThanOrEqual(field.frame.maxY, app.keyboards.firstMatch.frame.minY)
        attachScreenshot(of: app, named: "キーボードで打ち始めて広がった体重のシート")
    }
}
