import Foundation
import NuToriCore
import SwiftData

@Model
nonisolated final class CachedSyncState {
    @Attribute(.unique) var singletonKey: String
    var afterSequence: Int
    var hasCompletedInitialPull: Bool
    var readableKindsVersion: Int
    /// サーバーで決まるまで無い
    var startedOn: String?

    init(_ state: SyncState) {
        singletonKey = Self.onlyKey
        afterSequence = state.afterSequence
        hasCompletedInitialPull = state.hasCompletedInitialPull
        readableKindsVersion = state.readableKindsVersion
        startedOn = state.startedOn
    }

    func syncState() -> SyncState {
        SyncState(
            afterSequence: afterSequence,
            hasCompletedInitialPull: hasCompletedInitialPull,
            readableKindsVersion: readableKindsVersion,
            startedOn: startedOn
        )
    }

    func apply(_ state: SyncState) {
        afterSequence = state.afterSequence
        hasCompletedInitialPull = state.hasCompletedInitialPull
        readableKindsVersion = state.readableKindsVersion
        startedOn = state.startedOn
    }

    static let onlyKey = "sync-state"
}
