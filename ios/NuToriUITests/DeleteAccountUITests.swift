import XCTest

@MainActor
final class DeleteAccountUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", healthLatestKilograms: nil, timeZone: nil)
        app.openAccountScreen()
    }

    func test_消したらサインインの画面に戻ること() {
        app.confirmAccountDeletion()
        XCTAssertTrue(app.otherElements["signIn"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["毎朝の体重と、食事の写真だけ。"].exists)
        XCTAssertFalse(app.otherElements["timeline"].exists)
        attachScreenshot(of: app, named: "削除したあとのサインイン")
    }
}
