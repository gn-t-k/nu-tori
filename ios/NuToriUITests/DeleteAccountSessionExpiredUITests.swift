import XCTest

@MainActor
final class DeleteAccountSessionExpiredUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "account-deletion-unauthorized",
            healthLatestKilograms: nil, timeZone: nil)
        app.openAccountScreen()
    }

    func test_サインインし直しの画面を出すこと() {
        app.confirmAccountDeletion()
        XCTAssertTrue(
            app.staticTexts["もう一度サインインしてください。同じ Apple ID で続けると、記録はそのまま戻ります。"]
                .waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["signIn"].exists)
        XCTAssertFalse(app.otherElements["timeline"].exists)
        attachScreenshot(of: app, named: "削除でセッションを受け付けなかったとき")
    }
}
