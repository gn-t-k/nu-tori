#if DEBUG
    import Foundation
    import NuToriAPI
    import NuToriCore

    /// UI テストが `launchEnvironment` で渡す値。UI テストはアプリと別のプロセスで動くので、
    /// サーバーにつながず、サインインの状態と Apple の結果を、起動の値で差し替える
    struct UITestLaunch {
        let account: Account
        let appleSignIn: AppleSignIn
        let api: API

        /// `UI_TEST_ACCOUNT` があるときだけ、差し替えて起動する
        static var current: UITestLaunch? {
            let environment = ProcessInfo.processInfo.environment
            guard let account = environment["UI_TEST_ACCOUNT"].flatMap(Account.init(rawValue:))
            else {
                return nil
            }
            return UITestLaunch(
                account: account,
                appleSignIn: environment["UI_TEST_APPLE_SIGN_IN"].flatMap(
                    AppleSignIn.init(rawValue:)) ?? .succeeded,
                api: environment["UI_TEST_API"].flatMap(API.init(rawValue:)) ?? .online
            )
        }

        var appleSignInResult: AppleSignInResult {
            switch appleSignIn {
            case .succeeded:
                .authorized(
                    AppleSignInCredential(
                        idToken: "stub-id-token",
                        nonce: "stub-nonce",
                        authorizationCode: "stub-authorization-code",
                        appleUserId: "stub-apple-user"
                    )
                )
            case .cancelled: .cancelled
            case .failed: .failed
            }
        }

        func makeAccountSession() -> AccountSession {
            let keychain = InMemorySessionKeychain(token: account.hasSession ? "stub-session" : nil)
            return AccountSession(
                client: NuToriAPIClient(
                    serverURL: APIEnvironment.development.serverURL,
                    transport: StubAPITransport(behavior: api.transportBehavior),
                    sessionToken: { try? await keychain.sessionToken() }
                ),
                keychain: keychain,
                deviceStore: UserDefaultsSignInDeviceStore(defaults: makeDefaults()),
                syncStore: PlaceholderSyncStore(
                    queuedWrites: account.pendingWrites,
                    hasCompletedInitialPull: account.hasCompletedInitialPull
                ),
                appleCredentials: AuthorizedAppleCredentialChecker(),
                backgroundTransfers: PlaceholderBackgroundTransferStore(),
                healthAnchors: PlaceholderHealthAnchorStore(),
                analytics: PlaceholderAnalyticsSession(),
                errorReporting: PlaceholderErrorReportingSession(),
                timeZone: { .current },
                analyticsFlushTimeout: .seconds(3)
            )
        }

        enum Account: String {
            case signedOut = "signed-out"
            case signedIn = "signed-in"
            /// 初回の取得を終えていない
            case signedInFetching = "signed-in-fetching"
            case signInAgain = "sign-in-again"
            case signInAgainWithPendingWrites = "sign-in-again-with-pending-writes"

            fileprivate var hasSession: Bool {
                switch self {
                case .signedIn, .signedInFetching: true
                case .signedOut, .signInAgain, .signInAgainWithPendingWrites: false
                }
            }

            fileprivate var hasSignInAgainMark: Bool {
                switch self {
                case .signInAgain, .signInAgainWithPendingWrites: true
                case .signedOut, .signedIn, .signedInFetching: false
                }
            }

            fileprivate var hasCompletedInitialPull: Bool {
                switch self {
                case .signedInFetching: false
                case .signedOut, .signedIn, .signInAgain, .signInAgainWithPendingWrites: true
                }
            }

            fileprivate var pendingWrites: [PendingWrite] {
                switch self {
                case .signInAgainWithPendingWrites: [Self.pendingWeightWrite]
                case .signedOut, .signedIn, .signedInFetching, .signInAgain: []
                }
            }

            private static let pendingWeightWrite = PendingWrite(
                writeId: UUID(),
                enqueuedAt: .now,
                operation: .createWeightRecord(
                    WeightRecord(
                        id: UUID(),
                        kilograms: 72.4,
                        instant: .now,
                        timeZone: .current,
                        inputSource: .manual,
                        version: 1
                    )
                )
            )
        }

        enum AppleSignIn: String {
            case succeeded
            case cancelled
            case failed
        }

        enum API: String {
            case online
            case offline

            fileprivate var transportBehavior: StubAPITransport.Behavior {
                switch self {
                case .online: .online
                case .offline: .offline
                }
            }
        }

        /// アプリを消すと消える場所と同じ形で、起動のたびに空から始める
        private func makeDefaults() -> UserDefaults {
            let defaults = UserDefaults(suiteName: "app.nu-tori.ui-test.\(UUID().uuidString)")!
            defaults.set(true, forKey: UserDefaultsSignInDeviceStore.Key.hasOpened)
            if account.hasSession {
                defaults.set("stub-account", forKey: UserDefaultsSignInDeviceStore.Key.accountId)
                defaults.set(
                    "stub-apple-user", forKey: UserDefaultsSignInDeviceStore.Key.appleUserId)
            }
            if account.hasSignInAgainMark {
                defaults.set(true, forKey: UserDefaultsSignInDeviceStore.Key.signInAgainMark)
            }
            return defaults
        }
    }
#endif
