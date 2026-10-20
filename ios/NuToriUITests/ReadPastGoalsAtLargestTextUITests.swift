import XCTest

/// いちばん大きな文字で、目標の画面の過去の目標を読む。横に収まらない行は、結果を期間の下に送る。
/// 横に詰めたままだと、期間が日付の途中で折り返す（「減量 9 / 月28日〜」）
///
/// 行の中身は NuToriCore の単体テスト（GoalOverviewTests）が見る。ここで見るのは、結果が期間の下に来ること
@MainActor
final class ReadPastGoalsAtLargestTextUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "goal-switched-after-achieved",
            healthLatestKilograms: nil, now: .morningAfterNotice, timeZone: "Asia/Tokyo",
            textSize: .accessibility5)
        let goalLink = app.buttons["goal-link"]
        XCTAssertTrue(goalLink.waitForExistence(timeout: 5))
        goalLink.tap()
        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
    }

    func test_過去の目標の行で結果を期間の下に置くこと() {
        let pastGoal = app.descendants(matching: .any)["goal-past-goal"]
        XCTAssertTrue(app.scrollUntilExists(pastGoal, maxSwipes: 15))
        attachScreenshot(of: app, named: "いちばん大きな文字の過去の目標")
        XCTAssertGreaterThanOrEqual(
            pastGoal.staticTexts["−1.4 kg"].frame.minY,
            pastGoal.staticTexts["減量 9月28日〜10月4日"].frame.maxY)
    }
}
