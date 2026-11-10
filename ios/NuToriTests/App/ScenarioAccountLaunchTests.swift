#if DEBUG
    import Foundation
    import NuToriAPI
    import Testing

    @testable import NuTori

    @MainActor @Suite("場面のアカウントで開く起動の値")
    struct ScenarioAccountLaunchTests {
        @Test("セッションのトークンが無ければ、場面のアカウントで開かないこと")
        func withoutSessionToken() {
            #expect(ScenarioAccountLaunch(environment: ["SCENARIO_ACCOUNT_ID": "account"]) == nil)
        }

        @Test("サーバーの URL が無ければ、開発用の Worker につなぐこと")
        func withoutServerURL() {
            let launch = ScenarioAccountLaunch(environment: [
                "SCENARIO_SESSION_TOKEN": "token", "SCENARIO_ACCOUNT_ID": "account",
            ])
            #expect(
                launch
                    == ScenarioAccountLaunch(
                        sessionToken: "token", accountId: "account",
                        serverURL: APIEnvironment.development.serverURL))
        }

        @Test("サーバーの URL があれば、その URL につなぐこと")
        func withServerURL() {
            let launch = ScenarioAccountLaunch(environment: [
                "SCENARIO_SESSION_TOKEN": "token", "SCENARIO_ACCOUNT_ID": "account",
                "SCENARIO_SERVER_URL": "http://127.0.0.1:8799",
            ])
            #expect(launch?.serverURL == URL(string: "http://127.0.0.1:8799"))
        }
    }
#endif
