#if DEBUG
    import Foundation
    import NuToriAPI
    import Testing

    @testable import NuTori

    @MainActor @Suite("場面のアカウントで開く起動の値")
    struct ScenarioAccountLaunchTests {
        @MainActor @Suite("セッションのトークンが無いとき")
        struct WithoutSessionToken {
            let launch = ScenarioAccountLaunch(environment: ["SCENARIO_ACCOUNT_ID": "account"])

            @Test("場面のアカウントで開かないこと")
            func doesNotLaunch() {
                #expect(launch == nil)
            }
        }

        @MainActor @Suite("トークンと accountId だけがあるとき")
        struct WithoutServerURL {
            let launch: ScenarioAccountLaunch

            init() throws {
                launch = try #require(
                    ScenarioAccountLaunch(environment: [
                        "SCENARIO_SESSION_TOKEN": "token", "SCENARIO_ACCOUNT_ID": "account",
                    ]))
            }

            @Test("渡したセッションで、開発用の Worker につなぐこと")
            func connectsToDevelopment() {
                #expect(
                    launch
                        == ScenarioAccountLaunch(
                            sessionToken: "token", accountId: "account",
                            serverURL: APIEnvironment.development.serverURL))
            }
        }

        @MainActor @Suite("サーバーの URL もあるとき")
        struct WithServerURL {
            let launch: ScenarioAccountLaunch

            init() throws {
                launch = try #require(
                    ScenarioAccountLaunch(environment: [
                        "SCENARIO_SESSION_TOKEN": "token", "SCENARIO_ACCOUNT_ID": "account",
                        "SCENARIO_SERVER_URL": "http://127.0.0.1:8799",
                    ]))
            }

            @Test("その URL につなぐこと")
            func connectsToGivenURL() {
                #expect(launch.serverURL == URL(string: "http://127.0.0.1:8799"))
            }
        }
    }
#endif
