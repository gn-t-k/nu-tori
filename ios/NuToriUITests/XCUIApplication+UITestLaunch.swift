import XCTest

extension XCUIApplication {
    @MainActor static func launched(
        account: String,
        appleSignIn: String = "succeeded",
        api: String = "online",
        timeZone: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_ACCOUNT"] = account
        app.launchEnvironment["UI_TEST_APPLE_SIGN_IN"] = appleSignIn
        app.launchEnvironment["UI_TEST_API"] = api
        if let timeZone {
            app.launchEnvironment["TZ"] = timeZone
        }
        app.launch()
        return app
    }

    @MainActor func staticText(containing text: String) -> XCUIElement {
        staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
