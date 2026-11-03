import XCTest

/// 前回の体重があれば、体重のシートは中身の高さで開き、値の欄をキーボードで打ち始めたらキーボードのすぐ上に載る
@MainActor
final class WeightEntrySheetHeightWithPreviousWeightUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "previous-day", healthLatestKilograms: nil, timeZone: nil)
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        app.buttons["composer-weight"].tap()
        XCTAssertTrue(app.weightEntryPreviousLine.waitForExistence(timeout: 5))
    }

    func test_中身の下に大きな空きを残さずに開くこと() {
        XCTAssertTrue(app.waitUntilWeightEntrySheetFitsContent())
        attachScreenshot(of: app, named: "中身の高さで開いた体重のシート")
    }

    func test_値の欄を押して打ち始めるとシートがキーボードのすぐ上に載ること() {
        app.otherElements["weight-entry-sheet"].buttons["体重"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        XCTAssertTrue(
            app.waitUntilWeightEntrySheetSitsOnKeyboard(below: app.weightEntryPreviousLine))
        attachScreenshot(of: app, named: "キーボードのすぐ上に載った体重のシート")
    }

    func test_ステッパーを押してキーボードを閉じると中身の高さに戻ること() {
        let sheet = app.otherElements["weight-entry-sheet"]
        sheet.buttons["体重"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        sheet.buttons["0.1 kg 増やす"].tap()

        XCTAssertTrue(app.waitUntilWeightEntrySheetFitsContent())
        attachScreenshot(of: app, named: "キーボードを閉じて中身の高さに戻った体重のシート")
    }
}
