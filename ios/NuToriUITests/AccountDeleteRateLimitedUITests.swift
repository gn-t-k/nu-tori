import XCTest

@MainActor
final class AccountDeleteRateLimitedUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", api: "rate-limited")
        app.openAccountScreen()
    }

    func test_しばらくしてからもう一度押す1行を出すこと() {
        app.confirmAccountDeletion()
        XCTAssertTrue(
            app.staticTexts["削除できませんでした。しばらくしてから、もう一度押してください。"]
                .waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["signIn"].exists)
        attachScreenshot(of: app, named: "回数の歯止めで削除できないとき")
    }
}
