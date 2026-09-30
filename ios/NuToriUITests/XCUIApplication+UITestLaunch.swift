import XCTest

extension XCUIApplication {
    @MainActor static func launched(account: String, api: String = "online") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_ACCOUNT"] = account
        app.launchEnvironment["UI_TEST_API"] = api
        app.launch()
        return app
    }

    @MainActor func openAccountScreen() {
        XCTAssertTrue(buttons["accountButton"].waitForExistence(timeout: 5))
        buttons["accountButton"].tap()
        XCTAssertTrue(buttons["アカウントを削除"].waitForExistence(timeout: 5))
    }

    @MainActor func confirmAccountDeletion() {
        buttons["アカウントを削除"].tap()
        alerts["アカウントを削除しますか？"].buttons["アカウントを削除"].tap()
    }
}
