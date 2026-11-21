import XCTest

/// 目標を達成した月曜に、日のまとめの目標の行から目標の画面を開く → 「次の目標を選ぶ」でタイムラインの一番下に目標の設定のカードを広げる。
/// 体重の画面の「目標 ›」から目標の画面を開き、戻ると体重の画面に戻る。目標の画面の「体重の記録 ›」から体重の画面を開き、戻ると目標の画面に戻る。
///
/// 目標の行の小さな文と次の目標の行、「目標 ›」の目標体重は NuToriCore の単体テスト（DaySummaryGoalTests・TimelineSnapshotTests）が見る。
/// ここで見るのは、シートを閉じてから押して進むことと、体重の画面と目標の画面を互いの上に積んだときの行き来
@MainActor
final class OpenGoalFromDaySummaryAndWeightScreenUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "goal-achieved", healthLatestKilograms: nil,
            now: .morningAfterNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.buttons["goal-link"].waitForExistence(timeout: 5))
    }

    func test_日のまとめの目標の行から目標の画面を開き次の目標を選ぶで目標の設定を広げること() {
        openTodaySummary()
        let goalRow = app.buttons["day-summary-goal"]
        XCTAssertTrue(goalRow.exists)
        XCTAssertTrue(app.buttons["day-summary-next-goal"].exists)
        XCTAssertTrue(app.buttons["day-summary-weekly-review"].label.contains("10月5日〜11日（途中）"))
        attachScreenshot(of: app, named: "達成した日のまとめ")

        goalRow.tap()
        XCTAssertTrue(app.otherElements["day-summary"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "日のまとめから開いた目標の画面")

        app.tapBack(from: "目標")
        XCTAssertTrue(app.buttons["goal-link"].waitForExistence(timeout: 5))
        openTodaySummary()
        app.buttons["day-summary-next-goal"].tap()
        XCTAssertTrue(app.otherElements["day-summary"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(
            app.descendants(matching: .any)["goal-setup-flow"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "日のまとめから広げた目標の設定")
    }

    func test_体重の画面の目標から目標の画面を開き戻ると体重の画面に戻ること() {
        // タイムラインは一番下（今日）を見せて開くので、今日 7:00 の体重を押す
        let rows = app.buttons.matching(identifier: "weight-row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        rows.element(boundBy: rows.count - 1).tap()
        XCTAssertTrue(app.navigationBars["体重"].waitForExistence(timeout: 5))
        let goalLink = app.buttons["weight-goal-link"]
        XCTAssertTrue(app.scrollUntilExists(goalLink))
        XCTAssertTrue(goalLink.label.contains("70.1 kg"))
        attachScreenshot(of: app, named: "体重の画面の目標の行")

        goalLink.tap()
        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
        let back = app.navigationBars["目標"].buttons["体重"]
        XCTAssertTrue(back.exists)
        attachScreenshot(of: app, named: "体重の画面から開いた目標の画面")

        back.tap()
        XCTAssertTrue(app.navigationBars["体重"].waitForExistence(timeout: 5))
    }

    func test_目標の画面の体重の記録から体重の画面を開き戻ると目標の画面に戻ること() {
        app.buttons["goal-link"].tap()
        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
        let weightLink = app.buttons["goal-weight-record-link"]
        XCTAssertTrue(app.scrollUntilExists(weightLink))
        attachScreenshot(of: app, named: "目標の画面の体重の傾向のカード")

        weightLink.tap()
        XCTAssertTrue(app.navigationBars["体重"].waitForExistence(timeout: 5))
        // 今日の体重の画面を開く
        XCTAssertTrue(app.staticText(containing: "10月5日").waitForExistence(timeout: 5))
        let back = app.navigationBars["体重"].buttons["目標"]
        XCTAssertTrue(back.exists)
        attachScreenshot(of: app, named: "目標の画面から開いた体重の画面")

        back.tap()
        XCTAssertTrue(app.navigationBars["目標"].waitForExistence(timeout: 5))
    }

    private func openTodaySummary() {
        let ring = app.buttons["ring-2026-10-05"]
        XCTAssertTrue(ring.waitForExistence(timeout: 5))
        ring.tap()
        XCTAssertTrue(app.otherElements["day-summary"].waitForExistence(timeout: 5))
    }
}
