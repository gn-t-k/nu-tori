import XCTest

/// 文章と会話の主な流れ。プリセットで書いて送る → 読んでいます → 返事が届く → 食事の文章を送る → カードが出る → 会話として送り直す → 返事が届く → 作れなかった文章を送り直す → 返事が届く。
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
        XCTAssertTrue(field.waitForExistence(timeout: 5))
    }

    func test_書いて送ると返事が届き食事の文章を会話として送り直し作れなかった文章を送り直せること() {
        // プリセットは文面を書く欄に入れるだけで、送らない
        app.buttons.matching(identifier: "preset-chip").element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["composer-send"].waitForExistence(timeout: 5))
        app.buttons["composer-send"].tap()
        XCTAssertTrue(
            element("sent-text-bubble", containing: "フィードバック").waitForExistence(timeout: 5))
        XCTAssertTrue(element("reply-reading").waitForExistence(timeout: 10))
        attachScreenshot(of: app, named: "読んでいます")
        let feedback = element("reply", containing: "今日は朝ごはんから")
        XCTAssertTrue(feedback.waitForExistence(timeout: 30))
        XCTAssertTrue(element("reply-reading").waitForNonExistence(timeout: 5))
        attachScreenshot(of: app, named: "返事が届いた")

        send("昼は親子丼")
        // 吹き出しを残し、その下に文章の食事のカード（写真の場所なし）を出す。推定が届くと料理の名前になる
        let card = app.buttons["meal-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        XCTAssertTrue(waitUntil(card, matches: "label CONTAINS %@", "親子丼"))
        XCTAssertTrue(element("sent-text-bubble", containing: "昼は親子丼").exists)
        attachScreenshot(of: app, named: "文章の食事のカード")

        // 確かめずにカードが消え、返事が届く
        app.buttons["resend-as-conversation"].tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("reply", containing: "親子丼の話").waitForExistence(timeout: 30))
        attachScreenshot(of: app, named: "会話として送り直した返事")

        send("次の食事は？")
        let failed = element("reply-failed-line", containing: "返事を作れませんでした")
        XCTAssertTrue(failed.waitForExistence(timeout: 30))
        attachScreenshot(of: app, named: "作れなかった1行")
        app.buttons["reply-resend"].tap()
        XCTAssertTrue(failed.waitForNonExistence(timeout: 5))
        XCTAssertTrue(element("reply", containing: "野菜の多い定食").waitForExistence(timeout: 30))
        attachScreenshot(of: app, named: "送り直した返事")
    }

    /// 書く欄は、縦に伸びる TextField（UITextView）なので、種類を問わずに探す
    private var field: XCUIElement {
        app.descendants(matching: .any)["composer-field"]
    }

    private func send(_ text: String) {
        field.tap()
        field.typeText(text)
        app.buttons["composer-send"].tap()
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func element(_ identifier: String, containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier)
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
