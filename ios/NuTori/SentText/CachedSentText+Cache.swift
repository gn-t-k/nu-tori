import Foundation
import NuToriCore
import SwiftData

/// キャッシュの送った文章の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedSentText: KeyedCacheRow {
    nonisolated static func id(of record: SentText) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedSentText? {
        var descriptor = FetchDescriptor<CachedSentText>(
            predicate: #Predicate { $0.sentTextId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> SentText? {
        sentText()
    }
}
