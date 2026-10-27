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
        let sent = "ここまでの食事のフィードバックをください。"
        // Mac の Simulator.app はクリップボードを Mac と同期するので、コピーしてから貼るまでに Mac でコピーされると、その文が貼られる。
        // 違う文が貼られたら、書く欄を空にしてコピーからやり直す。コピーが壊れていれば、どの回も違う文になって落ちる
        var pasted = false
        for attempt in 1...3 {
            openBubbleMenu()
            if attempt == 1 {
                attachScreenshot(of: app, named: "吹き出しの長押しのメニュー")
            }
            app.buttons["コピー"].tap()
            pasted = pasteIntoComposer(expecting: sent)
            if pasted {
                break
            }
            // 同期のせいか、コピーが壊れたせいかを見分けられるよう、空にする前に貼られた文を残す
            attachScreenshot(of: app, named: "違う文が貼られた書く欄（\(attempt) 回め）")
            let value = XCTAttachment(string: app.composerField.value as? String ?? "")
            value.name = "違う文が貼られた書く欄の文（\(attempt) 回め）"
            value.lifetime = .keepAlways
            add(value)
            clearComposer()
        }
        XCTAssertTrue(pasted, "3回とも違う文が貼られた")
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

        // タイムラインの余白を押すと、選び終える
        tapTimelineMargin()
        XCTAssertTrue(selectable.waitForNonExistence(timeout: 5))
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "選び終えた返事")

        // 吹き出しも同じに選べる
        XCTAssertTrue(
            pressUntilMenuAppears(app.element("sent-text-bubble", containing: "フィードバック")))
        app.buttons["テキストを選択"].tap()
        // 選べる欄の識別子は、吹き出しの識別子に置き換わる
        XCTAssertTrue(app.textViews["sent-text-bubble"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "全体を選んだ吹き出し")
    }

    /// 押してもメニューが出なかったら、その画面と UI の木を残して押し直す。
    /// 吹き出しの長押しは、CI で UI テストの全部を回したときにだけ、まれにメニューが出ない（#750。このテストだけをくり返しても出ない）。理由を読めるよう、通った回でも残す
    private func pressUntilMenuAppears(_ element: XCUIElement) -> Bool {
        for attempt in 1...5 {
            element.press(forDuration: 1)
            if app.buttons["テキストを選択"].waitForExistence(timeout: 2) {
                return true
            }
            attachScreenshot(of: app, named: "長押しでメニューが出なかった画面（\(attempt) 回め）")
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "長押しでメニューが出なかった UI の木（\(attempt) 回め）"
            tree.lifetime = .keepAlways
            add(tree)
        }
        return false
    }

    private func openBubbleMenu() {
        XCTAssertTrue(
            pressUntilMenuAppears(app.element("sent-text-bubble", containing: "フィードバック")))
        XCTAssertTrue(app.buttons["コピー"].exists)
    }

    /// 書く欄にカーソルを置いてから長押しして、貼り付けのメニューから貼る。貼れた文が expected になったら true
    private func pasteIntoComposer(expecting expected: String) -> Bool {
        app.composerField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.composerField.press(forDuration: 1)
        let paste = editMenuItem(["ペースト", "Paste"])
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        return waitUntil(app.composerField, matches: "value == %@", expected, timeout: 5)
    }

    /// 貼った文を消し、タイムラインの余白を押してキーボードを下げ、吹き出しを1回めと同じ位置に戻す
    private func clearComposer() {
        let length = (app.composerField.value as? String)?.count ?? 0
        app.composerField.typeText(
            String(repeating: XCUIKeyboardKey.delete.rawValue, count: length))
        tapTimelineMargin()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    /// タイムラインの余白（日の見出しの上）を押す
    private func tapTimelineMargin() {
        app.otherElements["timeline"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .tap()
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
