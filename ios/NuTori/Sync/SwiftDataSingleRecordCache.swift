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

    /// `delete(model:)` は、保存の前に足した行を残す。残すと、次の保存で置き場に書かれるので、あとから消す
    func clear() throws {
        try context.delete(model: Row.self)
        if let row = try row() {
            context.delete(row)
        }
    }

    private func row() throws -> Row? {
        var descriptor = FetchDescriptor<Row>()
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
