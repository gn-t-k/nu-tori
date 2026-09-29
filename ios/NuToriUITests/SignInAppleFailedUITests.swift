import XCTest

@MainActor
final class SignInAppleFailedUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-out", appleSignIn: "failed")
        app.buttons["appleSignInButton"].tap()
    }

    func test_理由を1行で出し同じボタンでやり直せること() {
        XCTAssertTrue(app.staticTexts["サインインできませんでした。もう一度押してください。"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["appleSignInButton"].isEnabled)
        attachScreenshot(of: app, named: "失敗したあとの画面")
    }
}
