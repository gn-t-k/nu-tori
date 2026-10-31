import XCTest

@MainActor
final class SignOutWithoutPendingWritesUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", healthLatestKilograms: nil, timeZone: nil)
        app.openAccountScreen()
    }

    func test_確かめずにサインインし直しの画面に戻ること() {
        let signOutButton = app.buttons["サインアウト"]
        XCTAssertTrue(app.scrollUntilExists(signOutButton))
        attachScreenshot(of: app, named: "サインアウトの段のあるアカウントの画面")
        signOutButton.tap()
        XCTAssertTrue(app.otherElements["signIn"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["timeline"].exists)
        XCTAssertTrue(
            app.staticTexts["もう一度サインインしてください。同じ Apple ID で続けると、記録はそのまま戻ります。"]
                .exists)
        attachScreenshot(of: app, named: "サインアウトしたあとのサインイン")
    }
}
