import Foundation
import NuToriAPI
import NuToriCore
import Testing

@testable import NuTori

@Suite("バックグラウンドの更新")
struct RecordSyncBackgroundRefreshTests {
    @Suite("他のアプリがヘルスケアに体重を入れていたとき")
    @MainActor
    struct HealthHasWeight {
        let store: SwiftDataSyncStore
        let runtime: AppRuntime

        init() async throws {
            let clock = DeviceClock.live
            store = try SwiftDataSyncStore(inMemory: true)
            try await store.saveSyncState(
                SyncState(
                    afterSequence: 0,
                    hasCompletedInitialPull: true,
                    readableKinds: AppRecordKinds.registry.names,
                    startedOn: TimelineDayText.startedOn(for: clock.today())
                ))
            runtime = try makeRuntime(store: store, clock: clock)
        }

        @Test("ヘルスケアの体重を取り込んでから送ること")
        func importsHealthBeforeSync() async throws {
            let succeeded = await runtime.recordSync.refreshInBackground()

            #expect(succeeded)
            #expect(try await store.weightRecords().map(\.kilograms) == [70.5])
            #expect(try await store.pendingEntries().isEmpty)
        }
    }
}

@MainActor
private func makeRuntime(store: SwiftDataSyncStore, clock: DeviceClock) throws -> AppRuntime {
    let server = FakeSyncServer(
        .init(records: [], startedOn: TimelineDayText.startedOn(for: clock.today())))
    let defaults = try #require(UserDefaults(suiteName: "app.nu-tori.test.\(UUID().uuidString)"))
    defaults.set(true, forKey: UserDefaultsSignInDeviceStore.Key.hasOpened)
    defaults.set(FakeSyncServer.accountId, forKey: UserDefaultsSignInDeviceStore.Key.accountId)
    defaults.set("stub-apple-user", forKey: UserDefaultsSignInDeviceStore.Key.appleUserId)
    let photoRoot = FileManager.default.temporaryDirectory.appending(
        path: "test-meal-photos-\(UUID().uuidString)")
    let photoUploader = UITestMealPhotoUploader()
    return AppRuntime.assemble(
        AppRuntime.Parts(
            store: store,
            makeClient: { appBuildGate, sessionToken in
                NuToriAPIClient(
                    serverURL: APIEnvironment.development.serverURL,
                    transport: server,
                    appBuildGate: appBuildGate,
                    sessionToken: sessionToken
                )
            },
            appLockoutStore: UserDefaultsAppLockoutStore(defaults: defaults),
            keychain: InMemorySessionKeychain(token: FakeSyncServer.sessionToken),
            deviceStore: UserDefaultsSignInDeviceStore(defaults: defaults),
            healthStore: UITestHealthStore(
                authorization: .alreadyRequested, latestKilograms: 70.5, writeAuthorized: true,
                clock: clock),
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
