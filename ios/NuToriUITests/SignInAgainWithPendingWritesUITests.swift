import XCTest

@MainActor
final class SignInAgainWithPendingWritesUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "sign-in-again-with-pending-writes")
    }

    func test_まだ送っていない記録も送ることを添えること() {
        XCTAssertTrue(
            app.staticTexts[
                "もう一度サインインしてください。同じ Apple ID で続けると、記録はそのまま戻り、まだ送っていない記録も送ります。"
            ].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "送り待ちがあるときのサインインし直しの画面")
    }
}
