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
        let healthAuthorization: UITestHealthStore.Authorization
        let healthLatestKilograms: Double?
        let healthWriteAuthorized: Bool

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
                api: environment["UI_TEST_API"].flatMap(API.init(rawValue:)) ?? .online,
                healthAuthorization: environment["UI_TEST_HEALTH_AUTHORIZATION"]
                    == "not-yet-requested" ? .notYetRequested : .alreadyRequested,
                healthLatestKilograms: environment["UI_TEST_HEALTH_LATEST_KG"].flatMap(Double.init),
                healthWriteAuthorized: environment["UI_TEST_HEALTH_WRITE"] != "denied"
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

        func runtime() throws -> AppRuntime {
            let store = try SwiftDataSyncStore(inMemory: true)
            try store.prepareForUITest(
                state: seededSyncState(), pendingWrites: account.pendingWrites)
            let behavior = transportBehavior
            return AppRuntime.assemble(
                AppRuntime.Parts(
                    store: store,
                    makeClient: { sessionToken in
                        NuToriAPIClient(
                            serverURL: APIEnvironment.development.serverURL,
                            transport: StubAPITransport(behavior: behavior),
                            sessionToken: sessionToken
                        )
                    },
                    keychain: InMemorySessionKeychain(
                        token: account.hasSession ? "stub-session" : nil),
                    deviceStore: UserDefaultsSignInDeviceStore(defaults: seededIsolatedDefaults()),
                    healthStore: UITestHealthStore(
                        authorization: healthAuthorization,
                        latestKilograms: healthLatestKilograms,
                        writeAuthorized: healthWriteAuthorized
                    ),
                    startBackgroundDelivery: { _ in },
                    appleCredentials: AuthorizedAppleCredentialChecker(),
                    observation: ObservationSessions(
                        analytics: PlaceholderAnalyticsSession(),
                        errorReporting: PlaceholderErrorReportingSession()
                    )
                ))
        }

        private var transportBehavior: StubAPITransport.Behavior {
            if account == .signedInFetching {
                return .hangPull
            }
            switch api {
            case .online: return .online
            case .offline: return .offline
            case .weightRecords: return .weightRecords
            case .previousDay: return .previousDay
            case .previousDayPushOffline: return .previousDayPushOffline
            case .previousDayPushRejected: return .previousDayPushRejected
            case .weightScreen: return .weightScreen
            case .accountDeletionRateLimited: return .accountDeletionRateLimited
            case .accountDeletionUnauthorized: return .accountDeletionUnauthorized
            case .dayRing: return .dayRing
            }
        }

        /// サインイン済みで初回の取得を終えているときだけ、読み込み中を出さない
        private func seededSyncState() -> SyncState? {
            guard account.hasSession, account.hasCompletedInitialPull else { return nil }
            let today = CalendarDay(containing: .now, in: .current)
            return SyncState(
                afterSequence: 0,
                hasCompletedInitialPull: true,
                readableKindsVersion: SyncEngine.currentReadableKindsVersion,
                startedOn: TimelineDayText.startedOn(for: today)
            )
        }

        enum Account: String {
            case signedOut = "signed-out"
            case signedIn = "signed-in"
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
                case .signInAgainWithPendingWrites:
                    [
                        PendingWrite(
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
                    ]
                case .signedOut, .signedIn, .signedInFetching, .signInAgain: []
                }
            }
        }

        enum AppleSignIn: String {
            case succeeded
            case cancelled
            case failed
        }

        enum API: String {
            case online
            case offline
            case weightRecords = "weight-records"
            case previousDay = "previous-day"
            case previousDayPushOffline = "previous-day-push-offline"
            case previousDayPushRejected = "previous-day-push-rejected"
            case weightScreen = "weight-screen"
            case dayRing = "day-ring"
            case accountDeletionRateLimited = "account-deletion-rate-limited"
            case accountDeletionUnauthorized = "account-deletion-unauthorized"
        }

        /// アプリを消すと消える場所と同じ形で、起動のたびに空から始める
        private func seededIsolatedDefaults() -> UserDefaults {
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
