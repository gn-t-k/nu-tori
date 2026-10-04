import Foundation
import NuToriCore
import NuToriTestSupport

extension HealthSyncEngine {
    static let fixtureNow = Date(timeIntervalSince1970: 1_767_225_600)
    static let ownBundleId = "app.nu-tori.example"

    static func fixture(
        healthStore: HealthStoreMock,
        store: SyncBoxMock<RecordCacheMock>,
        errorReporting: ErrorReportingSessionMock = .ok(),
        now: @escaping @Sendable () -> Date = { fixtureNow }
    ) -> HealthSyncEngine {
        HealthSyncEngine(
            healthStore: healthStore,
            store: store,
            ownBundleId: ownBundleId,
            timeZone: { TimeZone(identifier: "Asia/Tokyo")! },
            now: now,
            errorReporting: errorReporting
        )
    }
}
