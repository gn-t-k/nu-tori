import Foundation
import NuToriCore
import SwiftData

@Model
nonisolated final class CachedSyncState {
    @Attribute(.unique) var singletonKey: String
    var afterSequence: Int
    var hasCompletedInitialPull: Bool
    /// 名前の順。SwiftData の集合の扱いに頼らないため配列で持つ
    var readableKinds: [String]
    /// サーバーで決まるまで無い
    var startedOn: String?

    init(_ state: SyncState) {
        singletonKey = Self.onlyKey
        afterSequence = state.afterSequence
        hasCompletedInitialPull = state.hasCompletedInitialPull
        readableKinds = state.readableKinds.sorted()
        startedOn = state.startedOn
    }

    func syncState() -> SyncState {
        SyncState(
            afterSequence: afterSequence,
            hasCompletedInitialPull: hasCompletedInitialPull,
            readableKinds: Set(readableKinds),
            startedOn: startedOn
        )
    }

    func apply(_ state: SyncState) {
        afterSequence = state.afterSequence
        hasCompletedInitialPull = state.hasCompletedInitialPull
        readableKinds = state.readableKinds.sorted()
        startedOn = state.startedOn
    }

    static let onlyKey = "sync-state"
}
