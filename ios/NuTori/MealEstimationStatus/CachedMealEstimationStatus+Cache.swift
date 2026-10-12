import Foundation
import NuToriCore
import SwiftData

/// キャッシュの食事の推定の状態の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedMealEstimationStatus: KeyedCacheRow {
    nonisolated static func id(of record: MealEstimationStatusSyncing.Status) -> UUID {
        record.mealId
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws
        -> CachedMealEstimationStatus?
    {
        var descriptor = FetchDescriptor<CachedMealEstimationStatus>(
            predicate: #Predicate { $0.mealId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> MealEstimationStatusSyncing.Status? {
        estimationStatus().map { MealEstimationStatusSyncing.Status(mealId: mealId, status: $0) }
    }
}
