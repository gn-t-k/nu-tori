import XCTest

/// 書く欄にカーソルがあるとき、タイムラインを動かすか押してキーボードを下げる。
/// 条件は、サインイン済みで、今日の体重を記録したあと（「体重」の丸が、書いていないときだけ出る）、書く欄にカーソルがあってキーボードが出ている
@MainActor
final class DismissKeyboardFromTimelineUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "previous-day", healthLatestKilograms: nil, timeZone: nil)
        XCTAssertTrue(app.staticText(containing: "72.6 kg").waitForExistence(timeout: 5))
        app.recordWeightTwoTenthsLower()
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        app.composerField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
    }

    func test_送ったあとも続けて書けタイムラインを下へ動かすとキーボードが下がって体重の丸が出ること() {
        app.composerField.typeText("散歩した")
        XCTAssertFalse(app.buttons["composer-weight"].exists)
        app.buttons["composer-send"].tap()
        XCTAssertTrue(app.staticText(containing: "散歩した").waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertFalse(app.buttons["composer-weight"].exists)

        // 欄を押し直さずに、続けて書いて送れる
        app.composerField.typeText("夜も歩く")
        app.buttons["composer-send"].tap()
        XCTAssertTrue(app.staticText(containing: "夜も歩く").waitForExistence(timeout: 5))

        dragTimeline(fromY: 0.25, toY: 0.4)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "タイムラインを動かして下げたキーボード")
    }

    func test_タイムラインを上へ動かしてもキーボードが下がること() {
        dragTimeline(fromY: 0.4, toY: 0.25)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "タイムラインを上へ動かして下げたキーボード")
    }

    func test_タイムラインの押せないところを押すとキーボードが下がること() {
        // 日の見出し。押しても何も起きない文
        let daySections = app.otherElements.matching(
            NSPredicate(format: "identifier BEGINSWITH 'day-section-'"))
        XCTAssertTrue(daySections.firstMatch.waitForExistence(timeout: 5))
        let dayHeading = daySections.element(boundBy: daySections.count - 1).staticTexts.firstMatch
        XCTAssertTrue(dayHeading.waitForExistence(timeout: 5))
        dayHeading.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "タイムラインを押して下げたキーボード")
    }

    func test_キーボードが出ているあいだに体重の行を押すと体重の画面へ潜ること() {
        let rows = app.buttons.matching(identifier: "weight-row")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        rows.element(boundBy: rows.count - 1).tap()
        XCTAssertTrue(app.descendants(matching: .any)["weight-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        attachScreenshot(of: app, named: "キーボードが出ているあいだに開いた体重の画面")
    }

    /// キーボードが出ているあいだにタイムラインが見えている範囲（1日の丸の帯と入力欄のあいだ）の中だけで、指を動かす。
    /// キーボードにも入力欄にも届かない、ふつうに動かすときの短い動き
    private func dragTimeline(fromY: CGFloat, toY: CGFloat) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: fromY))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: toY))
        start.press(forDuration: 0.1, thenDragTo: end)
    }
}
