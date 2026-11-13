#if DEBUG
    import Foundation
    import Testing

    @testable import NuTori

    @MainActor
    @Suite("手元のサーバーにつなぐ起動の値")
    struct UITestLaunchLocalServerTests {
        @MainActor
        @Suite("3つとも渡したとき")
        struct AllValues {
            let server: UITestLaunch.LocalServer?

            init() {
                server = UITestLaunch.LocalServer(environment: [
                    "UI_TEST_SERVER_URL": "http://127.0.0.1:8799",
                    "UI_TEST_SESSION_TOKEN": "local-session-token",
                    "UI_TEST_ACCOUNT_ID": "local-account",
                ])
            }

            @Test("手元のサーバーの URL とセッションを持つこと")
            func localServer() throws {
                let server = try #require(server)
                #expect(server.url == URL(string: "http://127.0.0.1:8799"))
                #expect(server.sessionToken == "local-session-token")
                #expect(server.accountId == "local-account")
            }
        }

        @MainActor
        @Suite("どれも渡さないとき")
        struct NoValues {
            let server: UITestLaunch.LocalServer?

            init() {
                server = UITestLaunch.LocalServer(environment: ["UI_TEST_ACCOUNT": "signed-in"])
            }

            @Test("偽の同期サーバーにつなぐよう nil になること")
            func fakeServer() {
                #expect(server == nil)
            }
        }
    }
#endif
