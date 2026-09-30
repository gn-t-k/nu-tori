import XCTest

@MainActor
final class SignInAppleCancelledUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-out", appleSignIn: "cancelled", healthLatestKilograms: nil)
        app.buttons["appleSignInButton"].tap()
    }

    func test_何も出さずにサインインの画面のままであること() {
        XCTAssertTrue(app.otherElements["signIn"].exists)
        XCTAssertFalse(app.staticText(containing: "サインインできませんでした").exists)
        XCTAssertTrue(app.buttons["appleSignInButton"].isEnabled)
        attachScreenshot(of: app, named: "やめたあとの画面")
    }
}
