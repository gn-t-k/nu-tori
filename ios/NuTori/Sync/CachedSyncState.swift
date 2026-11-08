import Foundation
import NuToriCore
import SwiftData

@Model
nonisolated final class CachedSyncState {
    @Attribute(.unique) var singletonKey: String
    var afterSequence: Int
    var hasCompletedInitialPull: Bool
    /// `RecordKindName` の rawValue。名前の順。SwiftData の集合の扱いに頼らないため配列で持つ。
    /// 今の `RecordKindName` に読めない名前は、読むときに捨てる
    var readableKinds: [String]
    /// サーバーで決まるまで無い
    var startedOn: String?

    init(_ state: SyncState) {
        singletonKey = Self.onlyKey
        // 値は apply が入れる。欄をすべて埋めるまで apply を呼べない（Swift の init の決まり）ので、省けない欄に仮の値を入れる
        afterSequence = 0
        hasCompletedInitialPull = false
        readableKinds = []
        apply(state)
    }

    func syncState() -> SyncState {
        SyncState(
            afterSequence: afterSequence,
            hasCompletedInitialPull: hasCompletedInitialPull,
            readableKinds: Set(readableKinds.compactMap(RecordKindName.init(rawValue:))),
            startedOn: startedOn
        )
    }

    func apply(_ state: SyncState) {
        afterSequence = state.afterSequence
        hasCompletedInitialPull = state.hasCompletedInitialPull
        readableKinds = Self.names(of: state.readableKinds)
        startedOn = state.startedOn
    }

    /// 保存する文字列（名前の順）。`RecordKindName` の rawValue なので、保存の形は今と同じ
    private static func names(of kinds: Set<RecordKindName>) -> [String] {
        kinds.map(\.rawValue).sorted()
    }

    static let onlyKey = "sync-state"
}
