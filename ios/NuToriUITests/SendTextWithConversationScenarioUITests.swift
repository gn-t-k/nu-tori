import XCTest

/// 文章と会話の主な流れ。プリセットで書いて送る → 読んでいます → 返事が届く → 食事の文章を送る → 吹き出しの下に食事の行がつながる → 会話として送り直す → 返事が届く → 作れなかった文章を送り直す → 返事が届く。
/// 条件は、サインイン済みで、API が会話の場面（偽のサーバーが送った文章の本文で答え方を決め、答えるのを3回めの取得まで待つ）のとき
@MainActor
final class SendTextWithConversationScenarioUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "conversation", healthLatestKilograms: nil,
            now: .morningBeforeNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.composerField.waitForExistence(timeout: 5))
    }

    func test_書いて送ると返事が届き食事の文章を会話として送り直し作れなかった文章を送り直せること() {
        // プリセットは文面を書く欄に入れるだけで、送らない
        app.buttons.matching(identifier: "preset-chip").element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["composer-send"].waitForExistence(timeout: 5))
        app.buttons["composer-send"].tap()
        XCTAssertTrue(
            app.element("sent-text-bubble", containing: "フィードバック").waitForExistence(timeout: 5))
        XCTAssertTrue(element("reply-reading").waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "読んでいます")
        let feedback = app.element("reply", containing: "今日は朝ごはんから")
        XCTAssertTrue(feedback.waitForExistence(timeout: 30))
        XCTAssertTrue(element("reply-reading").waitForNonExistence(timeout: 5))
        attachScreenshot(of: app, named: "返事が届いた")

        send("昼は親子丼")
        // 吹き出しの下に、文章の食事の行（写真の場所なし）をつなぐ。推定が届くと料理の名前になる
        let card = app.buttons["meal-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        XCTAssertTrue(waitUntil(card, matches: "label CONTAINS %@", "親子丼"))
        XCTAssertTrue(app.element("sent-text-bubble", containing: "昼は親子丼").exists)
        XCTAssertEqual(app.buttons.matching(identifier: "resend-as-conversation").count, 1)
        attachScreenshot(of: app, named: "吹き出しにつないだ文章の食事")

        // 確かめずに食事の行が消えて吹き出しだけが残り、返事が届く
        app.buttons["resend-as-conversation"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.element("sent-text-bubble", containing: "昼は親子丼").exists)
        XCTAssertTrue(app.element("reply", containing: "親子丼の話").waitForExistence(timeout: 30))
        attachScreenshot(of: app, named: "会話として送り直した返事")

        send("次の食事は？")
        let failed = app.element("reply-failed-line", containing: "返事を作れませんでした")
        XCTAssertTrue(failed.waitForExistence(timeout: 30))
        attachScreenshot(of: app, named: "作れなかった1行")
        app.buttons["reply-resend"].tap()
        XCTAssertTrue(failed.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.element("reply", containing: "野菜の多い定食").waitForExistence(timeout: 30))
        attachScreenshot(of: app, named: "送り直した返事")
    }

    private func send(_ text: String) {
        app.composerField.tap()
        app.composerField.typeText(text)
        app.buttons["composer-send"].tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
