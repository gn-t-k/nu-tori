#if DEBUG
    import Foundation
    import NuToriAPI
    import NuToriCore

    /// Mac で作った場面のアカウント（`server/e2e/cli/drive-device.ts` の scenario）で、デバッグビルドを開くための起動の値。
    /// 時の経過で起きる知らせを待たずに見るため、Sign in with Apple を通さず、渡されたセッションでサインインした状態で開く。
    /// 手順は `docs/agents/ios-mac.md` の「時の経過で起きる知らせを確かめる」。確かめの口の秘密の値はアプリに入れない
    struct ScenarioAccountLaunch: Equatable {
        let sessionToken: String
        let accountId: String
        /// 既定は開発用の Worker。手元の `wrangler dev` に向けるときに `SCENARIO_SERVER_URL` で渡す
        let serverURL: URL

        static var current: ScenarioAccountLaunch? {
            ScenarioAccountLaunch(environment: ProcessInfo.processInfo.environment)
        }

        init(sessionToken: String, accountId: String, serverURL: URL) {
            self.sessionToken = sessionToken
            self.accountId = accountId
            self.serverURL = serverURL
        }

        /// セッションのトークンが無ければ nil。トークンがあるのに足りない・読めない値は、ふだんの起動に戻すと気づけないので、その場で止める
        init?(environment: [String: String]) {
            guard let sessionToken = environment["SCENARIO_SESSION_TOKEN"] else { return nil }
            guard let accountId = environment["SCENARIO_ACCOUNT_ID"] else {
                preconditionFailure("SCENARIO_SESSION_TOKEN と一緒に SCENARIO_ACCOUNT_ID を渡す")
            }
            let serverURL: URL
            if let value = environment["SCENARIO_SERVER_URL"] {
                guard let url = URL(string: value) else {
                    preconditionFailure("SCENARIO_SERVER_URL を URL の形で渡す")
                }
                serverURL = url
            } else {
                serverURL = APIEnvironment.development.serverURL
            }
            self.init(sessionToken: sessionToken, accountId: accountId, serverURL: serverURL)
        }

        /// 場面のアカウントは使い捨てなので、記録の置き場・セッション・端末の記憶をメモリと起動ごとの UserDefaults に置き、ふだんのデバッグビルドのサインインとキャッシュに触れない。
        /// 値を外に出さないよう、ヘルスケア・通知・観測にはつながない
        func runtime() throws -> AppRuntime {
            let store = try SwiftDataSyncStore(inMemory: true)
            let photoUploader = BackgroundMealPhotoUploader()
            let photoRoot = FileManager.default.temporaryDirectory.appending(
                path: "scenario-meal-photos-\(UUID().uuidString)")
            let serverURL = serverURL
            return AppRuntime.assemble(
                AppRuntime.Parts(
                    store: store,
                    makeClient: {
                        NuToriAPIClient(serverURL: serverURL, appBuildGate: $0, sessionToken: $1)
                    },
                    appLockoutStore: UserDefaultsAppLockoutStore(defaults: isolatedDefaults()),
                    keychain: InMemorySessionKeychain(token: sessionToken),
                    deviceStore: UserDefaultsSignInDeviceStore(defaults: signedInDefaults()),
                    // 開発者のヘルスケアの体重が入ると、場面の判定が変わる
                    healthStore: UITestHealthStore(
                        authorization: .alreadyRequested, latestKilograms: nil,
                        writeAuthorized: true, clock: .live),
                    startBackgroundDelivery: { _ in },
                    // 確かめの口のアカウントには Apple の利用者が無いので、開くときの資格の確かめで捨てられないようにする
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
                    clock: .live,
                    subscriptionStore: StoreKitSubscriptionStore()
                ))
        }

        private func isolatedDefaults() -> UserDefaults {
            UserDefaults(suiteName: "app.nu-tori.scenario.\(UUID().uuidString)")!
        }

        /// 開いたことがあり、このアカウントでサインインした端末の記憶。Apple の利用者の ID は、資格の確かめを通すための仮の値
        private func signedInDefaults() -> UserDefaults {
            let defaults = isolatedDefaults()
            defaults.set(true, forKey: UserDefaultsSignInDeviceStore.Key.hasOpened)
            defaults.set(accountId, forKey: UserDefaultsSignInDeviceStore.Key.accountId)
            defaults.set(
                "scenario-apple-user", forKey: UserDefaultsSignInDeviceStore.Key.appleUserId)
            return defaults
        }
    }
#endif
