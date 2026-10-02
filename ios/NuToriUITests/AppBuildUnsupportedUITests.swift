import XCTest

@MainActor
final class AppBuildUnsupportedUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(
            account: "signed-in", api: "app-build-unsupported", healthLatestKilograms: nil,
            timeZone: nil)
    }

    func test_426を受け取ると締め出しの画面だけを出すこと() {
        XCTAssertTrue(app.otherElements["app-lockout"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["アップデートしてください"].exists)
        XCTAssertTrue(
            app.staticTexts["このバージョンの nu-tori は使えなくなりました。最新のバージョンに更新すると、続けて使えます。"]
                .exists)
        // デバッグビルドは、どこから入れた版か見分けられないので App Store
        XCTAssertTrue(app.buttons["App Store で更新"].exists)
        XCTAssertFalse(app.otherElements["timeline"].exists)
        XCTAssertFalse(app.buttons["account"].exists)
        XCTAssertFalse(app.buttons["composer-weight"].exists)
        XCTAssertFalse(app.buttons["composer-weight-unrecorded"].exists)
        attachScreenshot(of: app, named: "426 を受け取ったときの締め出しの画面")
    }
}
