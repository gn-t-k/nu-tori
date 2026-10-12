import Foundation
import NuToriCore
import SwiftData

/// キャッシュの返事の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedAiUtterance: KeyedCacheRow {
    nonisolated static func id(of record: AiUtterance) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedAiUtterance? {
        var descriptor = FetchDescriptor<CachedAiUtterance>(
            predicate: #Predicate { $0.utteranceId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> AiUtterance? {
        aiUtterance()
    }
}
