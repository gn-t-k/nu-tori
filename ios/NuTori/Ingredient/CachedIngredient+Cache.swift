import Foundation
import NuToriCore
import SwiftData

/// キャッシュの材料の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedIngredient: KeyedCacheRow {
    nonisolated static func id(of record: Ingredient) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedIngredient? {
        var descriptor = FetchDescriptor<CachedIngredient>(
            predicate: #Predicate { $0.ingredientId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> Ingredient? {
        ingredient()
    }
}
