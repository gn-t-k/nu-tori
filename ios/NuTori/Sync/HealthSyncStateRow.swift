import Foundation
import NuToriCore
import SwiftData

typealias HealthSyncStateRow = PendingStoreSchemaV1.HealthSyncStateRow

extension HealthSyncStateRow {
    convenience init(_ state: HealthSyncState) {
        self.init(
            singletonKey: Self.onlyKey,
            anchorData: state.anchor?.data,
            hasWrittenCachedManualRecords: state.hasWrittenCachedManualRecords
        )
    }

    func healthSyncState() -> HealthSyncState {
        HealthSyncState(
            anchor: anchorData.map { HealthAnchor(data: $0) },
            hasWrittenCachedManualRecords: hasWrittenCachedManualRecords
        )
    }

    func apply(_ state: HealthSyncState) {
        anchorData = state.anchor?.data
        hasWrittenCachedManualRecords = state.hasWrittenCachedManualRecords
    }

    static var onlyKey: String { "health-sync-state" }
}
