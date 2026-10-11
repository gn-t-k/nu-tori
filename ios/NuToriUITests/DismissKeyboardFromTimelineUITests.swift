import XCTest

/// 書く欄で送ったあと、タイムラインを下へ引いてキーボードを下げる。
/// 条件は、サインイン済みで、今日の体重を記録したあと（「体重」の丸が、書いていないときだけ出る）
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
    }

    func test_送ったあとも続けて書けタイムラインを下へ引くとキーボードが下がって体重の丸が出ること() {
        app.composerField.tap()
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

        // 指に合わせて下がるキーボードは、指がキーボードの上まで来ないと下がらないので、タイムラインから画面の下端まで引く
        let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        let screenBottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        dragStart.press(forDuration: 0.1, thenDragTo: screenBottom)
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "タイムラインを引いて下げたキーボード")
    }
}
