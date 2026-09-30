import XCTest

@MainActor
final class SignInOfflineUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-out", api: "offline", healthLatestKilograms: nil)
        app.buttons["appleSignInButton"].tap()
    }

    func test_インターネットにつながらない理由を出すこと() {
        XCTAssertTrue(
            app.staticTexts["インターネットにつながらないため、サインインできませんでした。つながるところで、もう一度押してください。"]
                .waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["timeline"].exists)
        attachScreenshot(of: app, named: "つながらないときの画面")
    }
}
