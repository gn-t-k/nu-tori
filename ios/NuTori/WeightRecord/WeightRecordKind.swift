import NuToriAPI
import NuToriCore
import SwiftData

/// 体重記録の、登録簿の1行。取りに行った変更と今の値をキャッシュに当てる。
/// 送る書き込みの形と、変更の見分け方は `WeightRecordSyncing`（NuToriCore）に置く
nonisolated struct WeightRecordKind: RecordKind {
    var name: String { syncing.name }

    func owns(_ change: SyncChange) -> Bool {
        syncing.owns(change)
    }

    func syncWrite(for entry: PendingEntry) throws -> SyncWrite {
        try syncing.syncWrite(for: entry)
    }

    /// 今の値を書いてから、削除の印の記録を消す。置き場に無い記録の削除の印は読み飛ばす（返し直されるため）
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        let current = syncing.current(from: changes)
        for record in current.records {
            try CachedWeightRecord.upsert(record, in: cache)
        }
        for recordId in current.removedRecordIds {
            if let row = try CachedWeightRecord.find(id: recordId, in: cache) {
                cache.delete(row)
            }
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedWeightRecord.self)
    }

    private let syncing = WeightRecordSyncing()
}
