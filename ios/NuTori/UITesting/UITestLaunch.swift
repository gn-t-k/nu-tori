#if DEBUG
    import Foundation
    import NuToriAPI
    import NuToriCore

    /// UI テストが `launchEnvironment` で渡す値。UI テストはアプリと別のプロセスで動くので、サーバーにつながず、サインインの状態と Apple の結果を、起動の値で差し替える
    struct UITestLaunch {
        let account: Account
        let appleSignIn: AppleSignIn
        let api: API
        let healthAuthorization: UITestHealthStore.Authorization
        let healthLatestKilograms: Double?
        let healthWriteAuthorized: Bool
        /// 入力欄の「写真」で、選ぶ画面を開かずに選んだことにする写真。nil なら標準の選ぶ画面を出す
        let pickedPhotos: PickedPhotos?
        /// 締め出しの記憶を置く UserDefaults の名前。同じ名前を渡して開き直すと、前に開いたときの締め出しを覚えている。
        /// nil なら、ほかの記憶と同じく、起動のたびに空から始める
        let lockoutDefaultsName: String?
        /// `UI_TEST_NOW` の時刻でほとんど止めた時計（`DeviceClock.frozen`）
        let clock: DeviceClock
        /// アプリの時計を、ホームへ出てから開き直すたびに1日進める。閉じているあいだに日付が変わったことにする
        let dayPassesOnReturn: Bool
        /// 場面の記録を、前に開いたときに取り終えてキャッシュに持っている状態で始める。false なら、開いてから取りに行く
        let cacheHoldsRecords: Bool
        /// 見本の人（`listingSampleScenario(_:)`）の昨日の夜の返事の行の数（`ListingSample.feedback(on:lineCount:)`）。撮る UI テストの場面（`ListingScene`）が渡す
        let listingReplyLineCount: Int
        /// 偽の同期サーバーの代わりにつなぐ、手元で立てたサーバー。nil なら偽の同期サーバーにつなぐ。
        /// 替わるのは API だけで、ヘルスケア・写真・StoreKit・Apple の資格の確かめは偽物のまま。UI テストは渡さず、`verify-ios` で手で開くときだけ渡す
        let localServer: LocalServer?

        /// 手元で立てたサーバー（`wrangler dev`）と、その確かめのサインインの口（`/v1/e2e/sessions`）で作ったセッション
        struct LocalServer {
            let url: URL
            let sessionToken: String
            let accountId: String

            /// どれも無ければ nil。一部だけのときは、偽の同期サーバーにつないだまま本物を確かめたと読み違えないよう、その場で止める
            init?(environment: [String: String]) {
                let names = ["UI_TEST_SERVER_URL", "UI_TEST_SESSION_TOKEN", "UI_TEST_ACCOUNT_ID"]
                guard names.contains(where: { environment[$0] != nil }) else { return nil }
                guard let url = environment["UI_TEST_SERVER_URL"].flatMap(URL.init(string:)),
                    let sessionToken = environment["UI_TEST_SESSION_TOKEN"],
                    let accountId = environment["UI_TEST_ACCOUNT_ID"]
                else {
                    preconditionFailure("\(names.joined(separator: "・")) は3つとも渡す")
                }
                self.url = url
                self.sessionToken = sessionToken
                self.accountId = accountId
            }
        }

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
                pickedPhotos: PickedPhotos.Source(environment: environment).map {
                    PickedPhotos(
                        source: $0,
                        loadingSeconds: environment["UI_TEST_PICKED_PHOTOS_LOADING_SECONDS"]
                            .flatMap(Double.init) ?? 0)
                },
                lockoutDefaultsName: environment["UI_TEST_LOCKOUT_DEFAULTS"],
                // UI テストは起動の値の TZ でタイムゾーンを決めるので、起動したときのタイムゾーンで止める
                clock: frozenClock(environment["UI_TEST_NOW"]),
                dayPassesOnReturn: environment["UI_TEST_DAY_PASSES_ON_RETURN"] != nil,
                cacheHoldsRecords: environment["UI_TEST_CACHE_HOLDS_RECORDS"] != nil,
                listingReplyLineCount: environment["UI_TEST_LISTING_REPLY_LINE_COUNT"].flatMap(
                    Int.init) ?? 0,
                localServer: LocalServer(environment: environment)
            )
        }

        struct PickedPhotos {
            let source: Source
            /// 読み終えるまでにかける秒数。読んでいるあいだの仮のカードを確かめるため
            let loadingSeconds: Double

            /// 選んだことにする写真の出どころ
            enum Source {
                /// 写真ごとに色を変えた無地の写真を、この枚数
                case solidColors(count: Int)
                /// このファイルの写真（シミュレーターから読める Mac のパス）
                case files([URL])

                /// 起動の値は、枚数かファイルのどちらか一方だけが渡る。どちらも無ければ nil
                init?(environment: [String: String]) {
                    if let files = environment["UI_TEST_PICKED_PHOTO_FILES"] {
                        self = .files(
                            files.split(separator: "\n").map { URL(filePath: String($0)) })
                    } else if let count = environment["UI_TEST_PICKED_PHOTOS"].flatMap(Int.init) {
                        self = .solidColors(count: count)
                    } else {
                        return nil
                    }
                }
            }

            var count: Int {
                switch source {
                case .solidColors(let count): count
                case .files(let files): files.count
                }
            }

            /// 選んだことにする写真の JPEG
            var jpegs: [Data] {
                switch source {
                case .solidColors(let count): UITestMealPhotos.jpegs(count: count)
                case .files(let files): UITestMealPhotos.jpegs(contentsOf: files)
                }
            }
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
            let scenario = syncScenario()
            try store.prepareForUITest(seededResults())
            if cacheHoldsRecords {
                try store.prepareForUITest([pulledResult(of: scenario, kinds: store.recordKinds)])
            }
            // 同じ偽の同期サーバーを、セッションが変わって作り直すクライアントでも使う
            let server = FakeSyncServer(scenario)
            // 始めに置く記録は起動したときの時刻で決め、アプリには進む時計を1つだけ渡す
            let clock = dayPassesOnReturn ? self.clock.advancingDayOnReturn() : self.clock
            return AppRuntime.assemble(
                AppRuntime.Parts(
                    store: store,
                    makeClient: { [localServer] appBuildGate, sessionToken in
                        if let localServer {
                            return NuToriAPIClient(
                                serverURL: localServer.url,
                                appBuildGate: appBuildGate,
                                sessionToken: sessionToken
                            )
                        }
                        return NuToriAPIClient(
                            serverURL: APIEnvironment.development.serverURL,
                            transport: server,
                            appBuildGate: appBuildGate,
                            sessionToken: sessionToken
                        )
                    },
                    appLockoutStore: UserDefaultsAppLockoutStore(
                        defaults: UserDefaults(
                            suiteName: lockoutDefaultsName
                                ?? "app.nu-tori.ui-test.lockout.\(UUID().uuidString)")!),
                    keychain: InMemorySessionKeychain(
                        token: account.hasSession ? seededSession.token : nil),
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
                    clock: clock,
                    subscriptionStore: subscriptionStore
                ))
        }

        /// StoreKit の口の偽物。アプリと課金画面の買うボタン（`PaywallStorefront.fixed`）が同じ結果を返すよう、場面から決める
        var subscriptionStore: UITestSubscriptionStore {
            UITestSubscriptionStore(
                purchaseResult: api == .subscriptionExpired ? .succeeds : .cancels)
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

        /// 場面の記録を取り終えたときに、キャッシュに当たる結果。通し番号は進めず、開いてからの取得で同じ記録がもう一度届く
        private func pulledResult(
            of scenario: FakeSyncServer.Scenario, kinds: [any SyncedRecordKind]
        ) -> SyncBoxResult {
            SyncBoxResult(
                kindChanges: kinds.map { kind in
                    KindChanges.owned(by: kind.name, in: scenario.records)
                }.filter { !$0.changes.isEmpty },
                syncState: SyncState(
                    afterSequence: 0,
                    hasCompletedInitialPull: true,
                    readableKinds: Set(kinds.map(\.name)),
                    startedOn: scenario.startedOn
                ))
        }

        /// 本物の時計に戻すと、結果が開いた時刻でまた変わるので、渡し忘れと読めない値はその場で止める
        private static func frozenClock(_ value: String?) -> DeviceClock {
            guard let value,
                let clock = DeviceClock.frozen(
                    atLaunchValue: value, in: .current, elapsed: DeviceClock.elapsedSinceCreated())
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
            case unevenDays = "uneven-days"
            case mealEstimation = "meal-estimation"
            /// 食事の推定は時刻を直すまで届かず、直したあとに取りに行ったときに届く。料理を足す・名前を直すと、次に取りに行ったときに推定し直しが届く
            case mealEdit = "meal-edit"
            /// 送った文章を本文で読み分けて答える。食事の文章には推定（親子丼）が届く
            case conversation
            case accountDeletionRateLimited = "account-deletion-rate-limited"
            case appBuildUnsupported = "app-build-unsupported"
            /// 今日 7:12 の体重を置き、目標の設定の4つの要求に答える（逆算できる人の初めての目標）
            case goalSetup = "goal-setup"
            /// 先週の月曜に立てた減量の目標の1週目を、今日の 0:05 に見直した。振り返りのカードと変更の知らせ、左上の目標の入口
            case weeklyReview = "weekly-review"
            /// `weeklyReview` に加えて、昨日の 21:00 に目標を達成したと判定した。達成の知らせから立て直す流れを開ける
            case goalAchieved = "goal-achieved"
            /// 昨日で無料体験が終わり、サブスクリプション切れ。買うと月額のサブスクリプション中に結びつく
            case subscriptionExpired = "subscription-expired"
            /// `subscriptionExpired` から、購入者のトークンを返さないようにした。課金画面はトークンを待ったままになる
            case subscriptionExpiredTokenPending = "subscription-expired-token-pending"
            /// 掲載情報と LP の手順の絵を撮る見本の人。記録と出どころは `listingSampleScenario()`
            case listingSample = "listing-sample"
            /// `listingSample` に加えて、選んだ写真の食事の推定を次の取得で終え、カレーライスにする
            case listingSamplePhotoEstimated = "listing-sample-photo-estimated"
            /// `listingSample` に加えて、「朝はお茶漬けを食べた」を食事と読み分け、推定してお茶漬けにする
            case listingSampleTextMeal = "listing-sample-text-meal"
            /// `listingSample` から今朝の体重を除いた。体重の知らせの時刻（8:00）を過ぎていれば、タイムラインにステッパーつきの知らせが出る
            case listingSampleBeforeWeighing = "listing-sample-before-weighing"
        }

        /// サインイン済みで始めるときのセッション。手元のサーバーにつなぐならそのセッション、でなければ偽の同期サーバーのもの
        private var seededSession: (token: String, accountId: String) {
            guard let localServer else {
                return (FakeSyncServer.sessionToken, FakeSyncServer.accountId)
            }
            return (localServer.sessionToken, localServer.accountId)
        }

        /// アプリを消すと消える場所と同じ形で、起動のたびに空から始める
        private func seededIsolatedDefaults() -> UserDefaults {
            let defaults = UserDefaults(suiteName: "app.nu-tori.ui-test.\(UUID().uuidString)")!
            defaults.set(true, forKey: UserDefaultsSignInDeviceStore.Key.hasOpened)
            if account.hasSession {
                defaults.set(
                    seededSession.accountId, forKey: UserDefaultsSignInDeviceStore.Key.accountId)
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
