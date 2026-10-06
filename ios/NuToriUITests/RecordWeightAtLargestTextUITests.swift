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

    func test_いちばん大きな文字でも未記録の体重を記録が画面に収まって見え押すと体重のシートが開くこと() {
        let weight = app.buttons["composer-weight-unrecorded"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        // 丸でなく、文字の入ったカプセルになっている
        XCTAssertGreaterThan(weight.frame.width, weight.frame.height)
        // 「撮る」「写真」の横に入らないので、その下の行に送られ、画面からはみ出さない
        XCTAssertGreaterThanOrEqual(weight.frame.minY, app.buttons["composer-capture"].frame.maxY)
        XCTAssertTrue(app.windows.firstMatch.frame.contains(weight.frame))
        attachScreenshot(of: app, named: "いちばん大きな文字の入力欄")
        weight.tap()
        XCTAssertTrue(app.otherElements["weight-entry-sheet"].waitForExistence(timeout: 5))
    }
}
