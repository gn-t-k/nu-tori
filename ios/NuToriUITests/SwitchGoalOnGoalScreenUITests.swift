import XCTest

/// 目標の画面の「目標を切り替える」 → 今の目標のカードがその場で目標の設定のカードに変わる → タイムラインに戻ると、タイムラインの一番下には描かない → もう一度目標の画面を開くと、広げたまま。
///
/// 流れのページと答えは NuToriCore の単体テスト（GoalSetupFlowTests）が見る。ここで見るのは、広げたカードを、広げた場所（目標の画面）にだけ描くこと
@MainActor
final class SwitchGoalOnGoalScreenUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "weekly-review", healthLatestKilograms: nil,
            now: .morningAfterNotice, timeZone: "Asia/Tokyo")
        let goalLink = app.buttons["goal-link"]
        XCTAssertTrue(goalLink.waitForExistence(timeout: 5))
        goalLink.tap()
        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
    }

    func test_目標の画面で目標を切り替えると広げたカードを目標の画面にだけ描くこと() {
        app.buttons["goal-switch"].tap()
        let flowCard = app.descendants(matching: .any)["goal-setup-flow"]
        XCTAssertTrue(flowCard.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["goal-switch-continuing-note"].exists)
        attachScreenshot(of: app, named: "目標の画面で広げたカード")

        app.tapBack()
        XCTAssertTrue(app.buttons["goal-link"].waitForExistence(timeout: 5))
        XCTAssertFalse(flowCard.exists)
        attachScreenshot(of: app, named: "戻ったタイムライン")

        app.buttons["goal-link"].tap()
        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
        XCTAssertTrue(flowCard.waitForExistence(timeout: 5))
    }
}
