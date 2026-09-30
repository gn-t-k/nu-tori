public import Foundation
public import NuToriAPI
public import NuToriCore

/// 体重記録の、メモリのキャッシュに当てる登録簿の1行。アプリの `WeightRecordKind` と同じ振る舞い
public struct MemoryWeightRecordKind: RecordKind {
    public init() {}

    public var name: String { syncing.name }

    public func owns(_ change: SyncChange) -> Bool {
        syncing.owns(change)
    }

    public func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        try syncing.syncWrite(for: entry)
    }

    public func rejection(
        of entry: PendingEntry,
        reason: SyncWriteResult.RejectionReason,
        revertedRecordIds: inout Set<UUID>
    ) throws -> KindRejection {
        try syncing.rejection(of: entry, reason: reason, revertedRecordIds: &revertedRecordIds)
    }

    public func apply(_ changes: [SyncChange], to cache: MemoryRecordCache) throws {
        let current = syncing.current(from: changes)
        for record in current.records {
            cache.upsert(record)
        }
        for recordId in current.removedRecordIds {
            cache.remove(recordId: recordId)
        }
    }

    public func erase(_ cache: MemoryRecordCache) throws {
        cache.clearRecords()
    }

    private let syncing = WeightRecordSyncing()
}
