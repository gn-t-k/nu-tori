import XCTest

/// 月曜のタイムラインに振り返りのカードと変更の知らせが出る → カードを押して週の振り返りを開く → 戻って左上の入口から目標の画面を開く。
///
/// カードと知らせを出す時刻と中身、週の振り返りと目標の画面の中身は NuToriCore の単体テスト（TimelineTests・WeekRecapTests・GoalOverviewTests）が見る。
/// ここで見るのは、同期で届いた週の見直しの記録がキャッシュに書かれてタイムラインに届くことと、押して進む2つの画面の行き来
@MainActor
final class OpenWeeklyReviewAndGoalFromMondayTimelineUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "weekly-review", healthLatestKilograms: nil,
            now: .morningAfterNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.buttons["weekly-review-card"].waitForExistence(timeout: 5))
    }

    func test_振り返りのカードから週の振り返りを開き戻って左上から目標の画面を開くこと() {
        let card = app.buttons["weekly-review-card"]
        XCTAssertTrue(card.label.contains("9月28日〜10月4日"))
        let changeNotice = app.descendants(matching: .any)["daily-guide-change-notice"]
        XCTAssertTrue(changeNotice.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "月曜のタイムライン")

        card.tap()
        XCTAssertTrue(app.navigationBars["週の振り返り"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticText(containing: "9月28日〜10月4日").waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "週の振り返り")

        app.tapBack(from: "週の振り返り")
        let goalLink = app.buttons["goal-link"]
        XCTAssertTrue(goalLink.waitForExistence(timeout: 5))
        goalLink.tap()

        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["goal-card"].exists)
        XCTAssertTrue(app.scrollUntilExists(app.descendants(matching: .any)["goal-energy-chart"]))
        XCTAssertTrue(app.scrollUntilExists(app.buttons["goal-weekly-review"]))
        attachScreenshot(of: app, named: "目標の画面")
    }
}
