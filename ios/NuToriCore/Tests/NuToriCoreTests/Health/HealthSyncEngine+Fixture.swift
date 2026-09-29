import Foundation
import NuToriCore

extension HealthSyncEngine {
    static let fixtureNow = Date(timeIntervalSince1970: 1_767_225_600)
    static let ownBundleId = "app.nu-tori.example"

    static func fixture(healthStore: HealthStoreMock, store: SyncStoreMock) -> HealthSyncEngine {
        HealthSyncEngine(
            healthStore: healthStore,
            store: store,
            ownBundleId: ownBundleId,
            timeZone: { TimeZone(identifier: "Asia/Tokyo")! },
            now: { fixtureNow }
        )
    }
}
