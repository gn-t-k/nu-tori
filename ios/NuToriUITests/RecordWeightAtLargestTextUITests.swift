import XCTest

@MainActor
final class RecordWeightAtLargestTextUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "online", healthLatestKilograms: nil, timeZone: nil,
            textSize: .accessibility5)
    }

    func test_いちばん大きな文字でも未記録の体重の丸が画面に収まって見え押すと体重のシートが開くこと() {
        let weight = app.buttons["composer-weight"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        // 「撮る」「写真」と同じ行に並び、画面からはみ出さない
        XCTAssertEqual(
            weight.frame.midY, app.buttons["composer-capture"].frame.midY, accuracy: 1)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(weight.frame))
        attachScreenshot(of: app, named: "いちばん大きな文字の入力欄")
        weight.tap()
        XCTAssertTrue(app.otherElements["weight-entry-sheet"].waitForExistence(timeout: 5))
    }
}
