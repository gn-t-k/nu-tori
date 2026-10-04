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
        /// 入力欄の「写真」で、選ぶ画面を開かずに選んだことにする写真の枚数。nil なら標準の選ぶ画面を出す
        let pickedMealPhotoCount: Int?
        /// 締め出しの記憶を置く UserDefaults の名前。同じ名前を渡して開き直すと、前に開いたときの締め出しを覚えている。
        /// nil なら、ほかの記憶と同じく、起動のたびに空から始める
        let lockoutDefaultsName: String?
        /// `UI_TEST_NOW` の時刻で止めた時計
        let clock: DeviceClock

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
                healthWriteAuthorized: environment["UI_TEST_HEALTH_WRITE"] != "denied",
                pickedMealPhotoCount: environment["UI_TEST_PICKED_PHOTOS"].flatMap(Int.init),
                lockoutDefaultsName: environment["UI_TEST_LOCKOUT_DEFAULTS"],
                // UI テストは起動の値の TZ でタイムゾーンを決めるので、起動したときのタイムゾーンで止める
                clock: frozenClock(environment["UI_TEST_NOW"])
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
            let photoUploader = UITestMealPhotoUploader()
            let photoRoot = FileManager.default.temporaryDirectory.appending(
                path: "ui-test-meal-photos-\(UUID().uuidString)")
            try store.prepareForUITest(seededResults())
            let behavior = transportBehavior
            let clock = self.clock
            return AppRuntime.assemble(
                AppRuntime.Parts(
                    store: store,
                    makeClient: { appBuildGate, sessionToken in
                        NuToriAPIClient(
                            serverURL: APIEnvironment.development.serverURL,
                            transport: StubAPITransport(behavior: behavior, clock: clock),
                            appBuildGate: appBuildGate,
                            sessionToken: sessionToken
                        )
                    },
                    appLockoutStore: UserDefaultsAppLockoutStore(
                        defaults: UserDefaults(
                            suiteName: lockoutDefaultsName
                                ?? "app.nu-tori.ui-test.lockout.\(UUID().uuidString)")!),
                    keychain: InMemorySessionKeychain(
                        token: account.hasSession ? "stub-session" : nil),
                    deviceStore: UserDefaultsSignInDeviceStore(defaults: seededIsolatedDefaults()),
                    healthStore: UITestHealthStore(
                        authorization: healthAuthorization,
                        latestKilograms: healthLatestKilograms,
                        writeAuthorized: healthWriteAuthorized,
                        clock: clock
                    ),
                    startBackgroundDelivery: { _ in },
                    appleCredentials: AuthorizedAppleCredentialChecker(),
                    observation: ObservationSessions(
                        analytics: PlaceholderAnalyticsSession(),
                        errorReporting: PlaceholderErrorReportingSession()
                    ),
                    mealPhotoFolders: MealPhotos.Folders(
                        originals: photoRoot.appending(path: "originals"),
                        uploads: photoRoot.appending(path: "uploads"),
                        fetched: photoRoot.appending(path: "fetched")
                    ),
                    mealPhotoUploader: photoUploader,
                    finishedMealPhotoUploads: photoUploader.finishedUploads,
                    reminderCenter: UITestReminderCenter(),
                    clock: clock
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
            case .weightScreenPushRejected: return .weightScreenPushRejected
            case .accountDeletionRateLimited: return .accountDeletionRateLimited
            case .accountDeletionUnauthorized: return .accountDeletionUnauthorized
            case .dayRing: return .dayRing
            case .mealEstimation: return .mealEstimation
            case .appBuildUnsupported: return .appBuildUnsupported
            }
        }

        /// 始める前の同期の状態と、送り待ちに残した記録
        private func seededResults() throws -> [SyncBoxResult] {
            try account.pendingRecords(at: clock).map {
                try WeightRecordSyncing().saving(
                    $0,
                    enqueuing: PendingWeightRecordWrite(
                        enqueuedAt: clock.now(), write: .createWeightRecord($0)))
            } + [SyncBoxResult(syncState: seededSyncState())]
        }

        /// 本物の時計に戻すと、結果が開いた時刻でまた変わるので、渡し忘れと読めない値はその場で止める
        private static func frozenClock(_ value: String?) -> DeviceClock {
            guard let value, let clock = DeviceClock.frozen(atLaunchValue: value, in: .current)
            else {
                preconditionFailure("UI_TEST_NOW を yyyy-MM-ddTHH:mm の形で渡す")
            }
            return clock
        }

        /// サインイン済みで初回の取得を終えているときだけ、読み込み中を出さない
        private func seededSyncState() -> SyncState? {
            guard account.hasSession, account.hasCompletedInitialPull else { return nil }
            let today = clock.today()
            return SyncState(
                afterSequence: 0,
                hasCompletedInitialPull: true,
                readableKinds: AppRecordKinds.registry.names,
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

            /// 送り待ちに残したまま始める、手で記録した体重
            fileprivate func pendingRecords(at clock: DeviceClock) -> [WeightRecord] {
                switch self {
                case .signInAgainWithPendingWrites:
                    [
                        WeightRecord(
                            id: UUID(),
                            kilograms: 72.4,
                            instant: clock.now(),
                            timeZone: clock.timeZone(),
                            inputSource: .manual,
                            version: 1
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
            case weightScreenPushRejected = "weight-screen-push-rejected"
            case dayRing = "day-ring"
            case mealEstimation = "meal-estimation"
            case accountDeletionRateLimited = "account-deletion-rate-limited"
            case accountDeletionUnauthorized = "account-deletion-unauthorized"
            case appBuildUnsupported = "app-build-unsupported"
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
