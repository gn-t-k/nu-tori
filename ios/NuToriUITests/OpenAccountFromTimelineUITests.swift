import XCTest

@MainActor
final class OpenAccountFromTimelineUITests: XCTestCase {
    private var app = XCUIApplication()

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        app = .launched(account: "signed-in", healthLatestKilograms: nil, timeZone: nil)
        app.openAccountScreen()
    }

    func test_ヘルスケアの行から読み書きする種類へ潜ること() {
        attachScreenshot(of: app, named: "アカウントの画面")
        app.buttons["ヘルスケア、読む・書く"].tap()
        XCTAssertTrue(app.navigationBars["ヘルスケア"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticText(containing: "体重、体脂肪率").exists)
        XCTAssertTrue(app.staticText(containing: "nu-tori で記録した体重。").exists)
        attachScreenshot(of: app, named: "ヘルスケアの読み書き")
    }

    func test_完了で閉じてタイムラインに戻ること() {
        app.navigationBars["アカウント"].buttons["完了"].tap()
        XCTAssertTrue(app.buttons["account"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["account-screen"].exists)
        attachScreenshot(of: app, named: "アカウントの画面を閉じたあとのタイムライン")
    }
}
