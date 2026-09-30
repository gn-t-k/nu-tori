import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

@MainActor final class AppRuntime {
    let container: ModelContainer
    let recordSync: RecordSync
    let model: RootModel

    init(container: ModelContainer, recordSync: RecordSync, model: RootModel) {
        self.container = container
        self.recordSync = recordSync
        self.model = model
    }

    static func forThisLaunch() -> AppRuntime {
        do {
            #if DEBUG
                if let launch = UITestLaunch.current {
                    return try launch.runtime()
                }
            #endif
            return try live()
        } catch {
            // 作り直しても開けないストアでは、記録を見せられない
            fatalError("記録の置き場を作れない")
        }
    }

    private static func live() throws -> AppRuntime {
        let store = try SwiftDataSyncStore(inMemory: false)
        let keychain = KeychainSessionKeychain()
        let deviceStore = UserDefaultsSignInDeviceStore(defaults: .standard)
        let client = NuToriAPIClient(
            environment: .forThisBuild,
            sessionToken: { try? await keychain.sessionToken() }
        )
        let healthStore = HealthKitHealthStore()
        let health = HealthSyncSession.live(
            syncStore: store,
            healthStore: healthStore,
            startBackgroundDelivery: { onWake in
                await healthStore.startDeliveringUpdates(onWake: onWake)
            }
        )
        let session = AccountSession(
            client: client,
            keychain: keychain,
            deviceStore: deviceStore,
            syncStore: store,
            appleCredentials: AppleIDCredentialChecker(),
            backgroundTransfers: PlaceholderBackgroundTransferStore(),
            healthAnchors: store,
            analytics: PlaceholderAnalyticsSession(),
            errorReporting: PlaceholderErrorReportingSession(),
            timeZone: { .current },
            analyticsFlushTimeout: .seconds(3)
        )
        let sync = RecordSync(
            store: store,
            client: client,
            accountSession: session,
            health: health,
            deviceId: { deviceStore.loadOrCreateDeviceId() },
            hasSession: { (try? await keychain.sessionToken()) != nil }
        )
        health.bindWakeHandler { [weak sync] in
            await sync?.importHealthAndSendPending()
        }
        let model = RootModel(accountSession: session, recordSync: sync, health: health)
        return AppRuntime(container: store.container, recordSync: sync, model: model)
    }
}
