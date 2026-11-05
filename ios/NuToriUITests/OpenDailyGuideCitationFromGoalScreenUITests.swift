import XCTest

/// 目標の画面の「1日の目安の出典 ›」 → 出典の画面に潜る → 戻ると目標の画面。
/// 審査の 1.4.1 に応えて、出典をアプリの中で見つけられること（#900）を確かめる。出典の文言は見ない
@MainActor
final class OpenDailyGuideCitationFromGoalScreenUITests: XCTestCase {
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

    func test_目標の画面から1日の目安の出典に潜って戻れること() {
        let citationLink = app.buttons["daily-guide-citation-link"]
        XCTAssertTrue(app.scrollUntilExists(citationLink))
        attachScreenshot(of: app, named: "出典の入口のある目標の画面")

        citationLink.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["daily-guide-citation-screen"].waitForExistence(
                timeout: 5))
        attachScreenshot(of: app, named: "1日の目安の出典")

        app.tapBack(from: "1日の目安の出典")
        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
    }
}
