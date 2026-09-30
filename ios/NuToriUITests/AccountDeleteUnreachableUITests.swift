import XCTest

@MainActor
final class AccountDeleteUnreachableUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "offline", healthLatestKilograms: nil, timeZone: nil)
        app.openAccountScreen()
    }

    func test_インターネットにつながらない1行を出すこと() {
        app.confirmAccountDeletion()
        XCTAssertTrue(
            app.staticTexts[
                "インターネットにつながらないため、削除できませんでした。つながるところで、もう一度押してください。"
            ].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["signIn"].exists)
        XCTAssertTrue(app.navigationBars["アカウント"].exists)
        XCTAssertTrue(app.buttons["アカウントを削除"].exists)
        attachScreenshot(of: app, named: "削除できないとき")
    }
}
