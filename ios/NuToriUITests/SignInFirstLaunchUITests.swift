import XCTest

@MainActor
final class SignInFirstLaunchUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-out", timeZone: nil)
    }

    func test_説明のひとことと同意のカードとAppleのボタンが出ること() {
        XCTAssertTrue(app.buttons["appleSignInButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["毎朝の体重と、食事の写真だけ。"].exists)
        XCTAssertTrue(app.staticTexts["続ける前に"].exists)
        XCTAssertTrue(app.staticText(containing: "続けると、これらに同意したことになります。").exists)
        XCTAssertTrue(app.links["プライバシーポリシー"].exists)
        XCTAssertFalse(app.otherElements["timeline"].exists)
        attachScreenshot(of: app, named: "サインインの画面")
    }

    func test_サインインするとタイムラインに置き換わり戻れないこと() {
        app.buttons["appleSignInButton"].tap()

        XCTAssertTrue(app.otherElements["timeline"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["signIn"].exists)
        XCTAssertFalse(app.navigationBars.buttons["戻る"].exists)
        XCTAssertTrue(app.buttons["アカウント"].exists)
        attachScreenshot(of: app, named: "サインインのあとのタイムライン")
    }
}
