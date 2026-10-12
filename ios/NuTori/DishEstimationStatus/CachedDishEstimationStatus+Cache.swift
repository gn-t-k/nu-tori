import Foundation
import NuToriCore
import SwiftData

/// キャッシュの料理ごとの推定の状態の行の引き方と、記録との行き来。SwiftData の adapter（`SwiftDataKeyedRecordCache`）が使う。
/// 保存は呼び出し側が行う
extension CachedDishEstimationStatus: KeyedCacheRow {
    nonisolated static func id(of record: DishEstimationStatusSyncing.Status) -> UUID {
        record.dishId
    }

    nonisolated static func find(id: UUID, in context: ModelContext) throws
        -> CachedDishEstimationStatus?
    {
        var descriptor = FetchDescriptor<CachedDishEstimationStatus>(
            predicate: #Predicate { $0.dishId == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    nonisolated func record() -> DishEstimationStatusSyncing.Status? {
        estimationStatus().map { DishEstimationStatusSyncing.Status(dishId: dishId, status: $0) }
    }
}
