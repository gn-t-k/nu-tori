import XCTest

/// 逆算できず、ヘルスケアから身長・生まれた年・性別を読めず、体重の記録も無い人が、目標を立てる知らせから向き・期限と進み、足りない値のページで身長・今の体重・生まれた年をホイールで選ぶ。
///
/// 並べる値と開いたときの位置は NuToriCore の単体テスト（GoalSetupMissingValuesTests）が見る。
/// ここで見るのは、行を押すとホイールのシートが出て、「完了」で入って閉じ、「キャンセル」で入れずに閉じる移り変わりと、テンキーが出ないこと
@MainActor
final class ChooseMissingValuesWithWheelsUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "goal-setup-missing-values", healthLatestKilograms: nil,
            timeZone: nil)
        let start = app.buttons["goal-setup-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(app.scrollUntilExists(start))
        start.tap()
        let lose = app.buttons["goal-setup-direction-lose"]
        XCTAssertTrue(lose.waitForExistence(timeout: 5))
        lose.tap()
        let next = app.buttons["goal-setup-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(app.buttons["goal-setup-height"].waitForExistence(timeout: 5))
    }

    func test_身長と今の体重と生まれた年をホイールで選んで目標案に進むこと() {
        choose(row: "goal-setup-height", wheel: "goal-setup-height-wheel", at: "170 cm")
        XCTAssertEqual(row("goal-setup-height").value as? String, "170 cm")

        choose(
            row: "goal-setup-current-weight", wheel: "goal-setup-current-weight-whole-wheel",
            at: "65")
        XCTAssertEqual(row("goal-setup-current-weight").value as? String, "65.0 kg")

        choose(row: "goal-setup-birth-year", wheel: "goal-setup-birth-year-wheel", at: "1990年")
        XCTAssertEqual(row("goal-setup-birth-year").value as? String, "1990年")

        let female = app.buttons["女性"]
        XCTAssertTrue(app.scrollUntilExists(female))
        female.tap()
        let activity = app.buttons.matching(identifier: "goal-setup-activity").firstMatch
        XCTAssertTrue(app.scrollUntilExists(activity))
        activity.tap()
        attachScreenshot(of: app, named: "そろった足りない値")

        let next = app.buttons["goal-setup-next"]
        XCTAssertTrue(app.scrollUntilExists(next))
        XCTAssertTrue(next.isEnabled)
        XCTAssertFalse(app.keyboards.element.exists)
        next.tap()
        XCTAssertTrue(app.buttons["goal-setup-proposal-standard"].waitForExistence(timeout: 5))
    }

    func test_身長のホイールの端が100cmと250cmであること() {
        assertEnds(
            row: "goal-setup-height", wheel: "goal-setup-height-wheel", top: "100 cm",
            bottom: "250 cm")
        attachScreenshot(of: app, named: "身長のホイールの下の端")
    }

    func test_今の体重の整数のホイールの端が20と300であること() {
        assertEnds(
            row: "goal-setup-current-weight", wheel: "goal-setup-current-weight-whole-wheel",
            top: "20", bottom: "300")
        attachScreenshot(of: app, named: "今の体重のホイールの下の端")
    }

    func test_生まれた年のホイールの端が選べる年の両端であること() {
        // 止めた時計の今日は 2026年で、年齢は 10〜120 歳を受け付ける。新しい年が上
        assertEnds(
            row: "goal-setup-birth-year", wheel: "goal-setup-birth-year-wheel", top: "2016年",
            bottom: "1906年")
        attachScreenshot(of: app, named: "生まれた年のホイールの下の端")
    }

    func test_キャンセルで値を入れずにホイールのシートが閉じること() {
        let height = row("goal-setup-height")
        height.tap()
        let wheel = pickerWheel("goal-setup-height-wheel")
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.adjust(toPickerWheelValue: "180 cm")
        attachScreenshot(of: app, named: "身長のホイールのシート")

        app.buttons["goal-setup-wheel-cancel"].tap()

        XCTAssertTrue(wheel.waitForNonExistence(timeout: 5))
        XCTAssertEqual(height.value as? String, "選ぶ")
        let next = app.buttons["goal-setup-next"]
        XCTAssertTrue(app.scrollUntilExists(next))
        XCTAssertFalse(next.isEnabled)
    }

    private func row(_ identifier: String) -> XCUIElement {
        app.buttons[identifier]
    }

    private func pickerWheel(_ identifier: String) -> XCUIElement {
        app.pickers[identifier].pickerWheels.firstMatch
    }

    /// 行を押してホイールのシートを出し、開いたときの位置を確かめ、行の右が「選ぶ」のまま「完了」で入れる
    private func choose(row identifier: String, wheel wheelIdentifier: String, at initial: String) {
        let row = row(identifier)
        XCTAssertTrue(app.scrollUntilExists(row))
        row.tap()
        let wheel = pickerWheel(wheelIdentifier)
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        XCTAssertEqual(wheel.value as? String, initial)
        XCTAssertEqual(row.value as? String, "選ぶ")
        XCTAssertFalse(app.keyboards.element.exists)
        app.buttons["goal-setup-wheel-confirm"].tap()
        XCTAssertTrue(wheel.waitForNonExistence(timeout: 5))
    }

    /// 行を押してホイールのシートを出し、上の端と下の端の値に合わせられることを確かめる。端より先に値が無いことは、並べる値を決める NuToriCore の単体テストが見る
    private func assertEnds(
        row identifier: String, wheel wheelIdentifier: String, top: String, bottom: String
    ) {
        let row = row(identifier)
        XCTAssertTrue(app.scrollUntilExists(row))
        row.tap()
        let wheel = pickerWheel(wheelIdentifier)
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))

        // 合わせた直後は描き直しの途中で値が空のことがあるので、合うまで待つ
        wheel.adjust(toPickerWheelValue: top)
        XCTAssertTrue(waitUntil(wheel, matches: "value == %@", top, timeout: 5))
        wheel.adjust(toPickerWheelValue: bottom)
        XCTAssertTrue(waitUntil(wheel, matches: "value == %@", bottom, timeout: 5))
    }
}
