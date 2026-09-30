import Foundation
import NuToriCore
import SwiftData

@Model
nonisolated final class CachedHealthSyncState {
    @Attribute(.unique) var singletonKey: String
    var anchorData: Data?
    var hasWrittenCachedManualRecords: Bool

    init(_ state: HealthSyncState) {
        singletonKey = Self.onlyKey
        anchorData = state.anchor?.data
        hasWrittenCachedManualRecords = state.hasWrittenCachedManualRecords
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

    static let onlyKey = "health-sync-state"
}
