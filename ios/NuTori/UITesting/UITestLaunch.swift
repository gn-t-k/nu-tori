#if DEBUG
    import Foundation
    import NuToriAPI
    import NuToriCore

    /// UI テストが `launchEnvironment` で渡す値。UI テストはアプリと別のプロセスで動くので、
    /// サーバーにつながず、サインイン済みの状態を起動の値で差し替える
    struct UITestLaunch {
        let api: API

        static var current: UITestLaunch? {
            let environment = ProcessInfo.processInfo.environment
            guard environment["UI_TEST_ACCOUNT"] == Account.signedIn.rawValue else {
                return nil
            }
            return UITestLaunch(
                api: environment["UI_TEST_API"].flatMap(API.init(rawValue:)) ?? .online
            )
        }

        var appleSignInResult: AppleSignInResult {
            .authorized(
                AppleSignInCredential(
                    idToken: "stub-id-token",
                    nonce: "stub-nonce",
                    authorizationCode: "stub-authorization-code",
                    appleUserId: "stub-apple-user"
                )
            )
        }

        func accountSessionWithStubs() -> AccountSession {
            let keychain = InMemorySessionKeychain(token: "stub-session")
            return AccountSession(
                client: NuToriAPIClient(
                    serverURL: APIEnvironment.development.serverURL,
                    transport: StubAPITransport(behavior: api.transportBehavior),
                    sessionToken: { try? await keychain.sessionToken() }
                ),
                keychain: keychain,
                deviceStore: UserDefaultsSignInDeviceStore(defaults: seededDefaults()),
                syncStore: PlaceholderSyncStore(queuedWrites: [], hasCompletedInitialPull: true),
                appleCredentials: AuthorizedAppleCredentialChecker(),
                backgroundTransfers: PlaceholderBackgroundTransferStore(),
                healthAnchors: PlaceholderHealthAnchorStore(),
                analytics: QuietAnalyticsSession(),
                errorReporting: QuietErrorReportingSession(),
                timeZone: { .current },
                analyticsFlushTimeout: .seconds(3)
            )
        }

        enum Account: String {
            case signedIn = "signed-in"
        }

        enum API: String {
            case online
            case offline
            case rateLimited = "rate-limited"
            case unauthorized
            case serverError = "server-error"

            fileprivate var transportBehavior: StubAPITransport.Behavior {
                switch self {
                case .online: .online
                case .offline: .offline
                case .rateLimited: .rateLimited
                case .unauthorized: .unauthorized
                case .serverError: .serverError
                }
            }
        }

        /// アプリを消すと消える場所と同じ形で、起動のたびに空から始める
        private func seededDefaults() -> UserDefaults {
            let name = "app.nu-tori.ui-test.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: name)!
            defaults.set(true, forKey: UserDefaultsSignInDeviceStore.Key.hasOpened)
            defaults.set("stub-account", forKey: UserDefaultsSignInDeviceStore.Key.accountId)
            defaults.set("stub-apple-user", forKey: UserDefaultsSignInDeviceStore.Key.appleUserId)
            return defaults
        }
    }

    private struct QuietAnalyticsSession: AnalyticsSession {
        func identify(accountId: String) async {}
        func capture(_ event: ClientUsageEvent) async {}
        func flushPendingEvents() async {}
        func reset() async {}
    }

    private struct QuietErrorReportingSession: ErrorReportingSession {
        func identify(accountId: String) async {}
        func report(_ failure: HandledFailure) async {}
        func clearUser() async {}
    }
#endif
