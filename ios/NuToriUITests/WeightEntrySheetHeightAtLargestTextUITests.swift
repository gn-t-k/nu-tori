import XCTest

/// いちばん大きな文字でも、中身の高さに合わせた体重のシートで中身が切れない
@MainActor
final class WeightEntrySheetHeightAtLargestTextUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "previous-day", healthLatestKilograms: nil, timeZone: nil,
            textSize: .accessibility5)
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        app.buttons["composer-weight"].tap()
        XCTAssertTrue(app.weightEntryPreviousLine.waitForExistence(timeout: 5))
    }

    func test_ステッパーと前回の行がシートの中で切れないこと() {
        XCTAssertTrue(app.waitUntilWeightEntrySheetFitsContent())
        let sheet = app.otherElements["weight-entry-sheet"]
        XCTAssertTrue(app.weightEntryRecordButton.isHittable)
        XCTAssertTrue(sheet.buttons["0.1 kg 減らす"].isHittable)
        XCTAssertTrue(sheet.buttons["0.1 kg 増やす"].isHittable)
        attachScreenshot(of: app, named: "いちばん大きな文字の体重のシート")
    }

    func test_打って添え書きが出てもキーボードに隠れないこと() {
        let sheet = app.otherElements["weight-entry-sheet"]
        sheet.buttons["体重"].tap()
        let field = sheet.textFields["体重の値"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "90")

        let typoLine = sheet.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "前回（")
        ).firstMatch
        XCTAssertTrue(typoLine.waitForExistence(timeout: 5))
        XCTAssertTrue(app.waitUntilWeightEntrySheetSitsOnKeyboard(below: typoLine))
        attachScreenshot(of: app, named: "いちばん大きな文字で添え書きが出た体重のシート")
    }
}
