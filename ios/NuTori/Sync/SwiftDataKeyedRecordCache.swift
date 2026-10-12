import NuToriCore
import SwiftData

/// SwiftData の、ID で引く記録のキャッシュ。NuToriCore の当て方（`CacheApplying`）が、行の形を知らずに読み書きする。
/// 行の形との行き来は、行（`KeyedCacheRow`）が持つ。保存は箱（`SwiftDataSyncStore`）がメインのコンテキストで行う
nonisolated struct SwiftDataKeyedRecordCache<Row: KeyedCacheRow>: KeyedRecordCache {
    let context: ModelContext

    func upsert(_ record: Row.Record) throws {
        if let row = try Row.find(id: Row.id(of: record), in: context) {
            try row.apply(record)
        } else {
            context.insert(try Row(record))
        }
    }

    func remove(id: Row.RecordID) throws {
        if let row = try Row.find(id: id, in: context) {
            context.delete(row)
        }
    }

    /// `delete(model:)` は、保存の前に足した行を残す。残すと、次の保存で置き場に書かれるので、あとから消す
    func removeAll() throws {
        try context.delete(model: Row.self)
        for row in try context.fetch(FetchDescriptor<Row>()) {
            context.delete(row)
        }
    }

    /// 読めない行（知らないタイムゾーンなど）は飛ばす
    func all() throws -> [Row.Record] {
        try context.fetch(FetchDescriptor<Row>()).compactMap { $0.record() }
    }
}
