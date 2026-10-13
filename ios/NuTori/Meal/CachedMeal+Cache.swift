import Foundation
import NuToriCore
import SwiftData

/// キャッシュの食事の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedMeal: KeyedCacheRow {
    nonisolated static func id(of record: Meal) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedMeal? {
        var descriptor = FetchDescriptor<CachedMeal>(predicate: #Predicate { $0.mealId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> Meal? {
        meal()
    }
}
