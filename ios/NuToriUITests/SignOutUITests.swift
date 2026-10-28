import XCTest

@MainActor
final class SignOutUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", healthLatestKilograms: nil, timeZone: nil)
        app.openAccountScreen()
    }

    func test_サインアウトしたらサインインし直しの画面に戻ること() {
        let signOutButton = app.buttons["サインアウト"]
        // 一覧の下のほうにあり、画面の外にあると作られないので、送って出す
        for _ in 0..<3 where !signOutButton.isHittable {
            app.swipeUp()
        }
        attachScreenshot(of: app, named: "サインアウトの段のあるアカウントの画面")
        signOutButton.tap()
        let alert = app.alerts["サインアウトしますか？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(
            alert.staticTexts["同じ Apple ID でサインインすると、記録はそのまま戻ります。"].exists)
        attachScreenshot(of: app, named: "サインアウトの確かめ")
        alert.buttons["サインアウト"].tap()
        XCTAssertTrue(app.otherElements["signIn"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["timeline"].exists)
        XCTAssertTrue(
            app.staticTexts["もう一度サインインしてください。同じ Apple ID で続けると、記録はそのまま戻ります。"]
                .exists)
        attachScreenshot(of: app, named: "サインアウトしたあとのサインイン")
    }
}
