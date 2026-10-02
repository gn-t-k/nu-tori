import XCTest

@MainActor
final class AppLockoutLiftedUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        let lockoutDefaults = "app.nu-tori.ui-test.lockout.\(UUID().uuidString)"
        XCUIApplication.rememberLockout(in: lockoutDefaults)
        // 最低バージョンを下げた日と同じく、開き直すとサーバーが 426 でない応答を返す
        app = .launched(
            account: "signed-in", healthLatestKilograms: nil, lockoutDefaults: lockoutDefaults,
            timeZone: nil)
    }

    func test_426でない応答を受け取るとふだんの画面に戻すこと() {
        XCTAssertTrue(app.otherElements["timeline"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["app-lockout"].exists)
        attachScreenshot(of: app, named: "締め出しが解けたタイムライン")
    }
}
