import XCTest

extension XCUIApplication {
    /// サーバーにつながず、サインインの状態と Apple の結果を起動の値で差し替えて起動する
    @MainActor static func launched(
        account: String,
        appleSignIn: String = "succeeded",
        api: String = "online"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_ACCOUNT"] = account
        app.launchEnvironment["UI_TEST_APPLE_SIGN_IN"] = appleSignIn
        app.launchEnvironment["UI_TEST_API"] = api
        app.launch()
        return app
    }

    @MainActor func staticText(containing text: String) -> XCUIElement {
        staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
