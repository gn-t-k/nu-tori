import XCTest

/// 逆算できず、ヘルスケアから身長・生まれた年・性別を読めず、体重の記録も無い人が、目標を立てる知らせから向き・期限と進み、足りない値のページで身長・今の体重・生まれた年をホイールで選ぶ。
///
/// 身長と今の体重の並べる値と、生まれた年の開いたときの位置が選べる年に無いときは、NuToriCore の単体テスト（GoalSetupMissingValuesTests）が見る。
/// ここで見るのは、行を押すとホイールのシートが出て、「完了」で入って閉じ、「キャンセル」で入れずに閉じる移り変わり、テンキーが出ないこと、開いたときの位置（170 cm、65.0 kg、1990年）、生まれた年のホイールの両端と回した年が入ること
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
        choose(row: "goal-setup-height", wheels: ["goal-setup-height-wheel": "170 cm"])
        XCTAssertEqual(row("goal-setup-height").value as? String, "170 cm")

        choose(
            row: "goal-setup-current-weight",
            wheels: [
                "goal-setup-current-weight-whole-wheel": "65",
                "goal-setup-current-weight-tenth-wheel": ".0 kg",
            ])
        XCTAssertEqual(row("goal-setup-current-weight").value as? String, "65.0 kg")

        choose(row: "goal-setup-birth-year", wheels: ["goal-setup-birth-year-wheel": "1990年"])
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

    func test_生まれた年のホイールの端が選べる年の両端で回した年が入ること() {
        let row = row("goal-setup-birth-year")
        XCTAssertTrue(app.scrollUntilExists(row))
        row.tap()
        let wheel = pickerWheel("goal-setup-birth-year-wheel")
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))

        // 止めた時計の今日は 2026年で、年齢は 10〜120 歳を受け付ける。新しい年が上。
        // 合わせた直後は描き直しの途中で値が空のことがあるので、合うまで待つ
        wheel.adjust(toPickerWheelValue: "2016年")
        XCTAssertTrue(waitUntil(wheel, matches: "value == %@", "2016年", timeout: 5))
        wheel.adjust(toPickerWheelValue: "1906年")
        XCTAssertTrue(waitUntil(wheel, matches: "value == %@", "1906年", timeout: 5))
        attachScreenshot(of: app, named: "生まれた年のホイールの下の端")
        app.buttons["goal-setup-wheel-confirm"].tap()

        XCTAssertTrue(waitUntil(row, matches: "value == %@", "1906年", timeout: 5))
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
        XCTAssertEqual(height.value as? String, "入力する")
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

    /// 行を押してホイールのシートを出し、開いたときの位置を確かめ、値を入れる前の表示のまま「完了」で入れる
    private func choose(row identifier: String, wheels initials: KeyValuePairs<String, String>) {
        let row = row(identifier)
        XCTAssertTrue(app.scrollUntilExists(row))
        row.tap()
        let wheels = initials.map { pickerWheel($0.key) }
        for (wheel, initial) in zip(wheels, initials.map(\.value)) {
            XCTAssertTrue(wheel.waitForExistence(timeout: 5))
            XCTAssertEqual(wheel.value as? String, initial)
        }
        XCTAssertEqual(row.value as? String, "入力する")
        XCTAssertFalse(app.keyboards.element.exists)
        app.buttons["goal-setup-wheel-confirm"].tap()
        XCTAssertTrue(wheels[0].waitForNonExistence(timeout: 5))
    }
}
