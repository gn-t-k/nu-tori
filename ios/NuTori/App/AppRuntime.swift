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

    private static func live() throws -> AppRuntime {
        let store = try SwiftDataSyncStore(inMemory: false)
        let keychain = KeychainSessionKeychain()
        let deviceStore = UserDefaultsSignInDeviceStore(defaults: .standard)
        let client = NuToriAPIClient(
            environment: .forThisBuild,
            sessionToken: { try? await keychain.sessionToken() }
        )
        let session = AccountSession(
            client: client,
            keychain: keychain,
            deviceStore: deviceStore,
            syncStore: store,
            appleCredentials: AppleIDCredentialChecker(),
            backgroundTransfers: PlaceholderBackgroundTransferStore(),
            healthAnchors: PlaceholderHealthAnchorStore(),
            analytics: PlaceholderAnalyticsSession(),
            errorReporting: PlaceholderErrorReportingSession(),
            timeZone: { .current },
            analyticsFlushTimeout: .seconds(3)
        )
        let sync = RecordSync(
            store: store,
            client: client,
            accountSession: session,
            deviceId: { deviceStore.loadOrCreateDeviceId() },
            hasSession: { (try? await keychain.sessionToken()) != nil },
            signedInAccountId: { (try? await deviceStore.signedInAccount())?.accountId }
        )
        let model = RootModel(accountSession: session, recordSync: sync)
        return AppRuntime(container: store.container, recordSync: sync, model: model)
    }
}
