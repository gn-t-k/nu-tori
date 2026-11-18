import XCTest

@MainActor
final class PaywallWaitsForAppAccountTokenUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "subscription-expired-token-pending",
            healthLatestKilograms: nil, timeZone: nil)
    }

    /// `SubscriptionStoreView` は、最初に作ったときの購入の選択肢を持ち続けることがあり、トークンの前に作ると、トークンの無い購入になる（#1025）
    func test_購入者のトークンを受け取るまで買うところを作らないこと() {
        app.buttons["composer-subscription-chip"].tap()

        XCTAssertTrue(app.activityIndicators["paywall-loading"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["paywall-purchase"].exists)
        attachScreenshot(of: app, named: "トークンを待つ課金画面")
    }
}
