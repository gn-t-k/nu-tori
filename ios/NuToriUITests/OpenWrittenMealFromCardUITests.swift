import XCTest

/// 文章の食事のカードは、「会話として送り直す」より上なら、文字の無いところを押しても食事の画面へ潜る。
/// 条件は、サインイン済みで、API が会話の場面（「昼は親子丼」に食事を作り、推定（親子丼）を数回あとの取得まで待つ）のとき。
/// 食事の画面から戻ると書く欄のキーボードが出直し、システムのキーボードの案内がカードを覆うことがあるので、押す場所ごとにテストを分ける
@MainActor
final class OpenWrittenMealFromCardUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "conversation", healthLatestKilograms: nil,
            now: .morningBeforeNotice, timeZone: "Asia/Tokyo")
        XCTAssertTrue(app.composerField.waitForExistence(timeout: 5))
        app.composerField.tap()
        app.composerField.typeText("昼は親子丼")
        app.buttons["composer-send"].tap()
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        XCTAssertTrue(waitUntil(card, matches: "label CONTAINS %@", "親子丼"))
    }

    func test_右端の余白を押すと食事の画面へ潜ること() {
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "余白から潜った食事の画面")
    }

    func test_右向きの矢印を押すと食事の画面へ潜ること() {
        card.images["chevron.right"].tap()
        XCTAssertTrue(app.navigationBars["食事"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "›から潜った食事の画面")
    }

    private var card: XCUIElement {
        app.buttons["meal-card"]
    }
}
