import XCTest

extension XCUIApplication {
    @MainActor static func launched(
        account: String,
        appleSignIn: String = "succeeded",
        api: String = "online",
        healthAuthorization: String = "already-requested",
        healthLatestKilograms: String?,
        healthWrite: String = "authorized",
        timeZone: String?
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_ACCOUNT"] = account
        app.launchEnvironment["UI_TEST_APPLE_SIGN_IN"] = appleSignIn
        app.launchEnvironment["UI_TEST_API"] = api
        app.launchEnvironment["UI_TEST_HEALTH_AUTHORIZATION"] = healthAuthorization
        if let healthLatestKilograms {
            app.launchEnvironment["UI_TEST_HEALTH_LATEST_KG"] = healthLatestKilograms
        }
        app.launchEnvironment["UI_TEST_HEALTH_WRITE"] = healthWrite
        if let timeZone {
            app.launchEnvironment["TZ"] = timeZone
        }
        app.launch()
        return app
    }

    @MainActor func staticText(containing text: String) -> XCUIElement {
        staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// 昨日の値から 0.2 kg 下げて記録する。初期値が 72.6 kg のとき、72.4 kg になる
    @MainActor func recordWeightTwoTenthsLower() {
        buttons["体重"].tap()
        let decrease = buttons["0.1 kg 減らす"]
        XCTAssertTrue(decrease.waitForExistence(timeout: 5))
        decrease.tap()
        decrease.tap()
        buttons["記録"].tap()
    }

    @MainActor func openAccountScreen() {
        XCTAssertTrue(buttons["account"].waitForExistence(timeout: 5))
        buttons["account"].tap()
        XCTAssertTrue(otherElements["account-screen"].waitForExistence(timeout: 5))
    }

    @MainActor func confirmAccountDeletion() {
        buttons["アカウントを削除"].tap()
        let delete = alerts["アカウントを削除しますか？"].buttons["アカウントを削除"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
    }
}
