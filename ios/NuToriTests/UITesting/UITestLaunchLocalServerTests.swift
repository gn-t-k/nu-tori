#if DEBUG
    import Foundation
    import Testing

    @testable import NuTori

    @MainActor
    @Suite("手元のサーバーにつなぐ起動の値")
    struct UITestLaunchLocalServerTests {
        @Test("3つとも渡すと、手元のサーバーとそのセッションにつなぐこと")
        func allValues() throws {
            let server = try #require(
                UITestLaunch.LocalServer(environment: [
                    "UI_TEST_SERVER_URL": "http://127.0.0.1:8799",
                    "UI_TEST_SESSION_TOKEN": "local-session-token",
                    "UI_TEST_ACCOUNT_ID": "local-account",
                ]))

            #expect(server.url == URL(string: "http://127.0.0.1:8799"))
            #expect(server.sessionToken == "local-session-token")
            #expect(server.accountId == "local-account")
        }

        @Test("どれも渡さないと、偽の同期サーバーにつなぐこと")
        func noValues() {
            #expect(UITestLaunch.LocalServer(environment: ["UI_TEST_ACCOUNT": "signed-in"]) == nil)
        }
    }
#endif
