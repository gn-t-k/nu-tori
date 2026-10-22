import XCTest

@MainActor
final class SubscribeFromComposerChipAfterFreeTrialUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "subscription-expired", healthLatestKilograms: nil,
            timeZone: nil)
    }

    func test_切れの知らせと押せない入力欄のチップから買うと入力欄が戻ること() {
        XCTAssertTrue(app.staticText(containing: "無料体験が終わりました").waitForExistence(timeout: 5))
        // 切れの知らせにはボタンが無い。昨日の「無料体験は今日まで」にはボタンがあるので、今日のカードの中だけを見る
        let endedNotice = app.otherElements.matching(identifier: "subscription-notice")
            .containing(NSPredicate(format: "label CONTAINS %@", "無料体験が終わりました")).firstMatch
        XCTAssertTrue(endedNotice.exists)
        XCTAssertFalse(endedNotice.buttons["subscription-notice-open-paywall"].exists)
        XCTAssertFalse(app.buttons["composer-capture"].isEnabled)
        XCTAssertFalse(app.buttons["composer-photos"].isEnabled)
        XCTAssertFalse(app.composerField.isEnabled)
        XCTAssertTrue(app.buttons["composer-weight-unrecorded"].isEnabled)
        attachScreenshot(of: app, named: "無料体験が終わった入力欄")

        app.buttons["composer-subscription-chip"].tap()
        let purchase = app.buttons["paywall-purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "チップから開いた課金画面")
        // 購入者のトークンを受け取るまでは押せない
        XCTAssertTrue(waitUntilEnabled(purchase))
        purchase.tap()

        XCTAssertTrue(purchase.waitForNonExistence(timeout: 5))
        XCTAssertTrue(waitUntilEnabled(app.buttons["composer-capture"]))
        XCTAssertFalse(app.buttons["composer-subscription-chip"].exists)
        XCTAssertFalse(app.staticText(containing: "無料体験が終わりました").exists)
        attachScreenshot(of: app, named: "買ったあとの入力欄")
    }

    private func waitUntilEnabled(_ element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
    }
}
