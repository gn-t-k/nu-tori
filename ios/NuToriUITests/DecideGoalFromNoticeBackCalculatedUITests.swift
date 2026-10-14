import XCTest

/// 逆算できる人が、目標を立てる知らせを開く → 減量 → 期限（そのまま「次へ」）→ 目標案 → 「この目標で始める」で、
/// カードが「目標を決めました」になり、今日の丸が1日の目安と比べる形になる。
///
/// どのページを出すか、どの要求をいつ出すかは NuToriCore の単体テスト（GoalSetupFlowTests）が見る。
/// ここで見るのは、カードの中のページの送りと、決めた目標の記録がキャッシュに書かれてタイムラインと帯に届くこと
@MainActor
final class DecideGoalFromNoticeBackCalculatedUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "goal-setup", healthLatestKilograms: nil, timeZone: nil)
        XCTAssertTrue(app.staticText(containing: "72.4 kg").waitForExistence(timeout: 5))
    }

    func test_知らせから減量の標準の案で目標を決めると決めたカードと目安と比べる丸になること() throws {
        let start = app.buttons["goal-setup-start"]
        XCTAssertTrue(app.scrollUntilExists(start))
        start.tap()

        let lose = app.buttons["goal-setup-direction-lose"]
        XCTAssertTrue(lose.waitForExistence(timeout: 5))
        lose.tap()
        let next = app.buttons["goal-setup-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()

        let standard = app.buttons["goal-setup-proposal-standard"]
        XCTAssertTrue(standard.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "目標案")
        app.buttons["goal-setup-proposal-start"].tap()

        let decided = app.staticTexts["goal-decided"]
        XCTAssertTrue(decided.waitForExistence(timeout: 5))
        XCTAssertTrue(decided.label.contains("目標を決めました"))
        XCTAssertTrue(decided.label.contains("69.2 kg"))
        // 今日の丸は、決めた目標の1日の目安と比べる（読み上げの値に目安を添える）
        XCTAssertTrue(
            waitUntil(
                app.buttons["ring-\(try today())"], matches: "value CONTAINS %@",
                "1日の目安 1,850 kcal"))
        attachScreenshot(of: app, named: "目標を決めました")
    }

    /// アプリと同じ止めた時計の今日（YYYY-MM-DD）
    private func today() throws -> String {
        let date = try UITestNow.morningBeforeNotice.date(in: .current)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
