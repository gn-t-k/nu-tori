import XCTest

/// いちばん大きな文字で、目標の画面と週の振り返りの、名前と値を横に並べた行を読む。
/// 横に収まらない行は、値を名前の下に送る。横に詰めたままだと、値が数字や単位の途中で折り返す（「72. / 3 kg」）
///
/// 行の中身は NuToriCore の単体テスト（GoalOverviewTests・WeekRecapTests）が見る。ここで見るのは、値が名前の下に来ること
@MainActor
final class ReadGoalAndWeeklyReviewAtLargestTextUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "weekly-review", healthLatestKilograms: nil,
            now: .morningAfterNotice, timeZone: "Asia/Tokyo", textSize: .accessibility5)
        let goalLink = app.buttons["goal-link"]
        XCTAssertTrue(goalLink.waitForExistence(timeout: 5))
        goalLink.tap()
        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
    }

    func test_今の目標のカードで目標を切り替えるを期間の下に置くこと() {
        let card = app.descendants(matching: .any)["goal-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "いちばん大きな文字の今の目標のカード")
        XCTAssertGreaterThanOrEqual(
            app.buttons["goal-switch"].frame.minY,
            card.staticTexts["減量 9月28日〜12月27日"].frame.maxY)
    }

    func test_今の1日の目安で日付を見出しの下に置くこと() {
        let dailyGuide = app.descendants(matching: .any)["goal-daily-guide"]
        XCTAssertTrue(dailyGuide.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "いちばん大きな文字の今の1日の目安")
        XCTAssertGreaterThanOrEqual(
            dailyGuide.staticTexts["10月5日から"].frame.minY,
            dailyGuide.staticTexts["今の1日の目安"].frame.maxY)
    }

    func test_週の振り返りの行で日付を名前の下に置くこと() {
        let weeklyReviewRow = app.buttons["goal-weekly-review"]
        XCTAssertTrue(app.scrollUntilExists(weeklyReviewRow, maxSwipes: 15))
        attachScreenshot(of: app, named: "いちばん大きな文字の週の振り返りの行")
        XCTAssertGreaterThanOrEqual(
            weeklyReviewRow.staticTexts["9月28日〜10月4日"].frame.minY,
            weeklyReviewRow.staticTexts["週の振り返り"].frame.maxY)
    }

    func test_タイムラインの変更の知らせで変わった量を新しい値の下に置くこと() {
        app.tapBack(from: "目標")
        let value = app.descendants(matching: .any)["daily-guide-change-value"]
        XCTAssertTrue(value.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "いちばん大きな文字のタイムライン")
        XCTAssertGreaterThanOrEqual(
            value.staticTexts["−30 kcal"].frame.minY,
            value.staticTexts["1,850 kcal"].frame.maxY)
    }

    func test_週の振り返りの日ごとの行で体重を日付の下に置くこと() {
        openWeeklyReview()
        let dayRow = app.buttons["weekly-review-day-2026-09-28"]
        XCTAssertTrue(app.scrollUntilExists(dayRow, maxSwipes: 15))
        attachScreenshot(of: app, named: "いちばん大きな文字の日ごとの行")
        XCTAssertGreaterThanOrEqual(
            dayRow.staticTexts["72.3 kg"].frame.minY,
            dayRow.staticTexts["9月28日（月）"].frame.maxY)
    }

    func test_次の週の1日の目安で変わった量を新しい値の下に置くこと() {
        openWeeklyReview()
        let nextWeekGuide = app.descendants(matching: .any)["weekly-review-next-week-guide"]
        XCTAssertTrue(app.scrollUntilExists(nextWeekGuide, maxSwipes: 15))
        attachScreenshot(of: app, named: "いちばん大きな文字の次の週の1日の目安")
        XCTAssertGreaterThanOrEqual(
            nextWeekGuide.staticTexts["−30 kcal"].frame.minY,
            nextWeekGuide.staticTexts["1,850 kcal"].frame.maxY)
    }

    /// 目標の画面の「週の振り返り」の行から、先週の週の振り返りを開く
    private func openWeeklyReview() {
        let weeklyReviewRow = app.buttons["goal-weekly-review"]
        XCTAssertTrue(app.scrollUntilExists(weeklyReviewRow))
        weeklyReviewRow.tap()
        XCTAssertTrue(app.navigationBars["週の振り返り"].waitForExistence(timeout: 5))
    }
}
