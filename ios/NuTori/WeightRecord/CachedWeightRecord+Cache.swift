import Foundation
import NuToriCore
import SwiftData

/// キャッシュの体重記録の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）と、`SwiftDataSyncStore` の読む口が使う。
/// 保存は呼び出し側が行う
extension CachedWeightRecord: KeyedCacheRow {
    nonisolated static func id(of record: WeightRecord) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedWeightRecord? {
        var descriptor = FetchDescriptor<CachedWeightRecord>(
            predicate: #Predicate { $0.recordId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> WeightRecord? {
        weightRecord()
    }
}
