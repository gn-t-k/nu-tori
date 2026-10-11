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

    func test_送ったあともキーボードが残りタイムラインを下へ引くと下がって体重の丸が出ること() {
        field.tap()
        field.typeText("散歩した")
        XCTAssertFalse(app.buttons["composer-weight"].exists)
        app.buttons["composer-send"].tap()
        XCTAssertTrue(app.staticText(containing: "散歩した").waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertFalse(app.buttons["composer-weight"].exists)

        // 指に合わせて下がるキーボードは、指がキーボードの上まで来ないと下がらないので、タイムラインから画面の下端まで引く
        let timeline = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        timeline.press(
            forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["composer-weight"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "タイムラインを引いて下げたキーボード")
    }

    /// 書く欄は、縦に伸びる TextField（UITextView）なので、種類を問わずに探す
    private var field: XCUIElement {
        app.descendants(matching: .any)["composer-field"]
    }
}
