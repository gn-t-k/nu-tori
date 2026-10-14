import Foundation
import NuToriCore
import SwiftData

/// キャッシュの推定消費カロリーの行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedExpenditureEstimate: KeyedCacheRow {
    nonisolated static func id(of record: ExpenditureEstimate) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws
        -> CachedExpenditureEstimate?
    {
        var descriptor = FetchDescriptor<CachedExpenditureEstimate>(
            predicate: #Predicate { $0.estimateId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> ExpenditureEstimate? {
        expenditureEstimate()
    }
}
