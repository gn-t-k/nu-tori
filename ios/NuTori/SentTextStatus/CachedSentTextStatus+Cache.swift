import Foundation
import NuToriCore
import SwiftData

/// キャッシュの送った文章の状態の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedSentTextStatus: KeyedCacheRow {
    nonisolated static func id(of record: SentTextStatusSyncing.Status) -> UUID {
        record.sentTextId
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedSentTextStatus?
    {
        var descriptor = FetchDescriptor<CachedSentTextStatus>(
            predicate: #Predicate { $0.sentTextId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> SentTextStatusSyncing.Status? {
        sentTextStatus().map { SentTextStatusSyncing.Status(sentTextId: sentTextId, status: $0) }
    }
}
