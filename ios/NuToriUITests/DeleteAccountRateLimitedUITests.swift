import XCTest

@MainActor
final class DeleteAccountRateLimitedUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "account-deletion-rate-limited",
            healthLatestKilograms: nil, timeZone: nil)
        app.openAccountScreen()
    }

    func test_しばらくしてから押し直す1行を出すこと() {
        app.confirmAccountDeletion()
        XCTAssertTrue(
            app.staticTexts["削除できませんでした。しばらくしてから、もう一度押してください。"]
                .waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["account-screen"].exists)
        XCTAssertFalse(app.otherElements["signIn"].exists)
        attachScreenshot(of: app, named: "回数の歯止めで削除できなかったとき")
    }
}
