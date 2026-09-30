import XCTest

@MainActor
final class SignInAgainUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "sign-in-again", healthLatestKilograms: nil)
    }

    func test_説明のひとことの代わりにサインインし直しの1行を出すこと() {
        XCTAssertTrue(
            app.staticTexts["もう一度サインインしてください。同じ Apple ID で続けると、記録はそのまま戻ります。"]
                .waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["毎朝の体重と、食事の写真だけ。"].exists)
        attachScreenshot(of: app, named: "サインインし直しの画面")
    }
}
