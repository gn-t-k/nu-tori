import Foundation
import NuToriAPI
import NuToriCore

/// この端末の置き場・API・ヘルスケアにつないだ同期の働きを作る
nonisolated struct DeviceSyncEngineSource: SyncEngineSource {
    let store: SwiftDataSyncStore
    let client: NuToriAPIClient
    let keychain: any SessionKeychain
    let deviceStore: UserDefaultsSignInDeviceStore
    let clock: DeviceClock
    let errorReporting: any ErrorReportingSession
    let healthEngine: HealthSyncEngine
    let mealPhotos: MealPhotos

    func hasSession() async -> Bool {
        (try? await keychain.sessionToken()) != nil
    }

    func signedInAccountId() async -> String? {
        (try? await deviceStore.signedInAccount())?.accountId
    }

    func engine(accountId: String) async -> SyncEngine {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return SyncEngine(
            store: store,
            client: client,
            accountId: accountId,
            device: SyncDevice(
                deviceId: deviceStore.loadOrCreateDeviceId(),
                appVersion: Bundle.main.appVersion,
                osVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
            ),
            timeZone: clock.timeZone,
            now: clock.now,
            readableKinds: AppRecordKinds.registry.names,
            errorReporting: errorReporting,
            weightHealthExport: healthEngine,
            nutritionHealthExport: healthEngine,
            mealPhotos: mealPhotos
        )
    }
}
