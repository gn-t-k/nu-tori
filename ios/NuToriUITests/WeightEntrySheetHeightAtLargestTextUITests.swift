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
        XCTAssertTrue(app.buttons["composer-weight-unrecorded"].waitForExistence(timeout: 5))
        app.buttons["composer-weight-unrecorded"].tap()
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
}
