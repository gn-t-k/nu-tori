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

    static func forThisLaunch() -> AppRuntime? {
        do {
            #if DEBUG
                if let launch = UITestLaunch.current {
                    return try launch.runtime()
                }
            #endif
            return try live()
        } catch is SwiftDataSyncStore.NotOpened {
            // 一時的な失敗ではファイルを残してある。この回は開かず、次に開いたときにやり直す
            return nil
        } catch {
            // 作り直しても開けないストアでは、記録を見せられない
            fatalError("記録の置き場を作れない")
        }
    }

    /// 本番と UI テストで違う部品。配線は `assemble(_:)` が1つだけ持つ
    struct Parts {
        let store: SwiftDataSyncStore
        /// セッショントークンを受け取って API クライアントを作る（API のトランスポートが違う）
        let makeClient:
            @Sendable (_ sessionToken: @escaping @Sendable () async -> String?) ->
                NuToriAPIClient
        let keychain: any SessionKeychain
        let deviceStore: UserDefaultsSignInDeviceStore
        let healthStore: any HealthStore
        let startBackgroundDelivery: @Sendable (@escaping @Sendable () async -> Void) async -> Void
        let appleCredentials: any AppleCredentialChecker
        let observation: ObservationSessions
    }

    private static func live() throws -> AppRuntime {
        let healthStore = HealthKitHealthStore()
        // Sendable のクロージャからは MainActor の値を読めないので、先に取り出す
        let environment = APIEnvironment.forThisBuild
        return assemble(
            Parts(
                store: try SwiftDataSyncStore(inMemory: false),
                makeClient: { NuToriAPIClient(environment: environment, sessionToken: $0) },
                keychain: KeychainSessionKeychain(),
                deviceStore: UserDefaultsSignInDeviceStore(defaults: .standard),
                healthStore: healthStore,
                startBackgroundDelivery: { onWake in
                    await healthStore.startDeliveringUpdates(onWake: onWake)
                },
                appleCredentials: AppleIDCredentialChecker(),
                observation: ObservationSessions.live()
            ))
    }

    static func assemble(_ parts: Parts) -> AppRuntime {
        let store = parts.store
        let keychain = parts.keychain
        let deviceStore = parts.deviceStore
        let observation = parts.observation
        let client = parts.makeClient { try? await keychain.sessionToken() }
        let health = HealthSyncSession.live(
            syncStore: store,
            healthStore: parts.healthStore,
            errorReporting: observation.errorReporting,
            startBackgroundDelivery: parts.startBackgroundDelivery
        )
        let session = AccountSession(
            client: client,
            keychain: keychain,
            deviceStore: deviceStore,
            syncStore: store,
            appleCredentials: parts.appleCredentials,
            backgroundTransfers: PlaceholderBackgroundTransferStore(),
            healthAnchors: store,
            analytics: observation.analytics,
            errorReporting: observation.errorReporting,
            timeZone: { .current },
            analyticsFlushTimeout: .seconds(3)
        )
        let sync = RecordSync(
            store: store,
            client: client,
            accountSession: session,
            health: health,
            deviceId: { deviceStore.loadOrCreateDeviceId() },
            hasSession: { (try? await keychain.sessionToken()) != nil },
            signedInAccountId: { (try? await deviceStore.signedInAccount())?.accountId },
            errorReporting: observation.errorReporting
        )
        health.bindWakeHandler { [weak sync] in
            await sync?.importHealthAndSendPending()
        }
        let model = RootModel(accountSession: session, recordSync: sync, health: health)
        return AppRuntime(container: store.container, recordSync: sync, model: model)
    }
}
