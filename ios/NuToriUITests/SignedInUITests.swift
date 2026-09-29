import XCTest

@MainActor
final class SignedInUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in")
    }

    func test_サインインの画面を出さずにタイムラインを開くこと() {
        XCTAssertTrue(app.otherElements["timeline"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["signIn"].exists)
        XCTAssertFalse(app.staticTexts["記録を読み込んでいます…"].exists)
        attachScreenshot(of: app, named: "サインイン済みのタイムライン")
    }
}
