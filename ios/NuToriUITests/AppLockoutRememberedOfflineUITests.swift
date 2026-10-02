import XCTest

@MainActor
final class AppLockoutRememberedOfflineUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        let lockoutDefaults = "app.nu-tori.ui-test.lockout.\(UUID().uuidString)"
        XCUIApplication.rememberLockout(in: lockoutDefaults)
        // サインインの画面を出す状態で開き直し、締め出しの画面がそれより上に出るかも確かめる
        app = .launched(
            account: "signed-out", api: "offline", healthLatestKilograms: nil,
            lockoutDefaults: lockoutDefaults, timeZone: nil)
    }

    func test_電波が無くても開き直すと締め出しの画面を出すこと() {
        XCTAssertTrue(app.otherElements["app-lockout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["アップデートしてください"].exists)
        XCTAssertTrue(app.buttons["App Store で更新"].exists)
        XCTAssertFalse(app.otherElements["signIn"].exists)
        attachScreenshot(of: app, named: "電波が無いときに開き直した締め出しの画面")
    }
}
