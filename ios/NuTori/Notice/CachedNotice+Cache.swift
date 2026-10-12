import Foundation
import NuToriCore
import SwiftData

/// キャッシュの知らせの行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedNotice: KeyedCacheRow {
    nonisolated static func id(of record: Notice) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedNotice? {
        var descriptor = FetchDescriptor<CachedNotice>(predicate: #Predicate { $0.noticeId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> Notice? {
        notice()
    }
}
