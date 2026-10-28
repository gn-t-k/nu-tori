import XCTest

@MainActor
final class RestoreFromPaywallWithoutPurchaseUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "subscription-expired", healthLatestKilograms: nil,
            timeZone: nil)
    }

    func test_購入を復元を押すと結果の1行が開いた直後の位置で見えること() {
        app.buttons["composer-subscription-chip"].tap()
        XCTAssertTrue(app.buttons["paywall-purchase"].waitForExistence(timeout: 5))

        app.buttons["購入を復元"].tap()

        let message = app.staticTexts["paywall-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertTrue(message.isHittable)
        attachScreenshot(of: app, named: "購入を復元を押したあとの課金画面")
    }
}
