import XCTest

/// 逆算できる人が、目標を立てる知らせを開く → 減量 → 期限（そのまま「次へ」）→ 目標案 → 「この目標で始める」で、カードが「目標を決めました」になり、今日の丸が1日の目安と比べる形になる。維持を選ぶと、保つ体重と1日の目安の値の行が出る。
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

        // 食べた日の日のまとめは、決めた目標の1日の目安と比べる形になる
        app.composerField.tap()
        app.composerField.typeText("昼は親子丼")
        app.buttons["composer-send"].tap()
        XCTAssertTrue(waitUntil(app.buttons["meal-card"], matches: "label CONTAINS %@", "親子丼"))
        attachScreenshot(of: app, named: "時刻をカードの外に置いた吹き出しと食事")
        app.buttons["ring-\(try today())"].tap()
        XCTAssertTrue(app.otherElements["day-summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            waitUntil(
                app.descendants(matching: .any)["day-food"], matches: "label CONTAINS %@",
                "/ 1,850 kcal"))
        attachScreenshot(of: app, named: "1日の目安と比べる日のまとめ")
    }

    func test_知らせから維持を選ぶと保つ体重と1日の目安の値の行が出ること() {
        let start = app.buttons["goal-setup-start"]
        XCTAssertTrue(app.scrollUntilExists(start))
        start.tap()

        let maintain = app.buttons["goal-setup-direction-maintain"]
        XCTAssertTrue(maintain.waitForExistence(timeout: 5))
        maintain.tap()

        let maintenance = app.descendants(matching: .any)["goal-setup-maintenance"]
        XCTAssertTrue(maintenance.waitForExistence(timeout: 5))
        XCTAssertTrue(maintenance.label.contains("72.0 kg を保つ"))
        XCTAssertTrue(maintenance.label.contains("1日の目安"))
        XCTAssertTrue(maintenance.label.contains("2,250 kcal"))
        attachScreenshot(of: app, named: "維持のページ")
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
