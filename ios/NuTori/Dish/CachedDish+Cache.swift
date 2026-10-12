import Foundation
import NuToriCore
import SwiftData

/// キャッシュの料理の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedDish: KeyedCacheRow {
    nonisolated static func id(of record: Dish) -> UUID {
        record.id
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws -> CachedDish? {
        var descriptor = FetchDescriptor<CachedDish>(predicate: #Predicate { $0.dishId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> Dish? {
        dish()
    }
}
