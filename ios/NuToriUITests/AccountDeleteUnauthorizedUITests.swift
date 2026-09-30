import XCTest

@MainActor
final class AccountDeleteUnauthorizedUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "unauthorized", healthLatestKilograms: nil, timeZone: nil)
        app.openAccountScreen()
    }

    func test_サインインの画面を出すこと() {
        app.confirmAccountDeletion()
        let message = "もう一度サインインしてください。同じ Apple ID で続けると、記録はそのまま戻ります。"
        XCTAssertTrue(app.staticTexts[message].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["signIn"].exists)
        XCTAssertFalse(app.otherElements["timeline"].exists)
        attachScreenshot(of: app, named: "セッションを受け付けなかったとき")
    }
}
