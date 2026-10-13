import NuToriCore
import SwiftData

/// SwiftData の、1件だけの記録のキャッシュ。NuToriCore の当て方（`CacheApplying`）が、行の形を知らずに読み書きする。
/// 行の形との行き来は、行（`SingleCacheRow`）が持つ。保存は箱（`SwiftDataSyncStore`）がメインのコンテキストで行う
nonisolated struct SwiftDataSingleRecordCache<Row: SingleCacheRow>: SingleRecordCache {
    let context: ModelContext

    func read() throws -> Row.Record? {
        try row()?.record()
    }

    func write(_ record: Row.Record) throws {
        if let row = try row() {
            try row.apply(record)
        } else {
            context.insert(try Row(record))
        }
    }

    func clear() throws {
        try context.deleteAll(Row.self)
    }

    private func row() throws -> Row? {
        var descriptor = FetchDescriptor<Row>()
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
