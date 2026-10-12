import XCTest

/// 発言を長押しして、全体をコピーするか、その場で範囲を選ぶ。
/// 条件は、サインイン済みで、API が会話の場面（偽のサーバーが送った文章の本文で答え方を決める）で、プリセットで書いて送った文章に返事が届いたあと
@MainActor
final class CopyAndSelectUtteranceUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "conversation", healthLatestKilograms: nil,
            now: .morningBeforeNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.composerField.waitForExistence(timeout: 5))
        app.buttons.matching(identifier: "preset-chip").element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["composer-send"].waitForExistence(timeout: 5))
        app.buttons["composer-send"].tap()
        XCTAssertTrue(reply.waitForExistence(timeout: 30))
    }

    func test_吹き出しを長押ししてコピーすると書く欄に貼り付けられること() {
        let bubble = app.element("sent-text-bubble", containing: "フィードバック")
        bubble.press(forDuration: 1)
        XCTAssertTrue(app.buttons["コピー"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["テキストを選択"].exists)
        attachScreenshot(of: app, named: "吹き出しの長押しのメニュー")
        app.buttons["コピー"].tap()

        // 書く欄にカーソルを置いてから長押しして、貼り付けのメニューを出す
        app.composerField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.composerField.press(forDuration: 1)
        let paste = editMenuItem(["ペースト", "Paste"])
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        XCTAssertTrue(
            waitUntil(app.composerField, matches: "value == %@", "ここまでの食事のフィードバックをください。"))
        attachScreenshot(of: app, named: "コピーした文章を貼り付けた書く欄")
    }

    func test_返事と吹き出しを長押ししてテキストを選択を選ぶとその場で全体が選ばれ余白を押すと戻ること() {
        // 返事のメニューは、返事を出し終えてから出る
        XCTAssertTrue(pressUntilMenuAppears(reply))
        XCTAssertTrue(app.buttons["コピー"].exists)
        attachScreenshot(of: app, named: "返事の長押しのメニュー")
        app.buttons["テキストを選択"].tap()

        let selectable = app.textViews["selectable-text"]
        XCTAssertTrue(selectable.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "全体を選んだ返事")
        // 選んだ範囲を押すと、iOS の標準のメニューが出る
        selectable.tap()
        XCTAssertTrue(editMenuItem(["コピー", "Copy"]).waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "選んだ範囲のメニュー")

        // タイムラインの余白（日の見出しの上）を押すと、選び終える
        app.otherElements["timeline"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .tap()
        XCTAssertTrue(selectable.waitForNonExistence(timeout: 5))
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "選び終えた返事")

        // 吹き出しも同じに選べる
        app.element("sent-text-bubble", containing: "フィードバック").press(forDuration: 1)
        XCTAssertTrue(app.buttons["テキストを選択"].waitForExistence(timeout: 5))
        app.buttons["テキストを選択"].tap()
        // 選べる欄の識別子は、吹き出しの識別子に置き換わる
        XCTAssertTrue(app.textViews["sent-text-bubble"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "全体を選んだ吹き出し")
    }

    private func pressUntilMenuAppears(_ element: XCUIElement) -> Bool {
        for _ in 0..<5 {
            element.press(forDuration: 1)
            if app.buttons["テキストを選択"].waitForExistence(timeout: 2) {
                return true
            }
        }
        return false
    }

    private var reply: XCUIElement {
        app.element("reply", containing: "今日は朝ごはんから")
    }

    /// 選んだ範囲や書く欄に出る iOS の標準のメニューの項目。名前はシミュレータの言語で変わる
    private func editMenuItem(_ labels: [String]) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", labels))
            .matching(
                NSPredicate(
                    format: "elementType IN %@",
                    [
                        XCUIElement.ElementType.menuItem.rawValue,
                        XCUIElement.ElementType.button.rawValue,
                    ])
            )
            .firstMatch
    }
}
