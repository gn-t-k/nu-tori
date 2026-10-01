import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 推定の状態の、登録簿の1行。取りに行った状態をキャッシュに当てる。
/// サーバーだけが書く種類なので、送る書き込みは持たない（`MealEstimationStatusSyncing`）
nonisolated struct MealEstimationStatusRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 届いた順に状態を書いてから、削除の印の状態を消す。食事がまだ無い状態も置く（届く順は約束しない）
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        let current = syncing.current(from: changes)
        for status in current.statuses {
            try CachedMealEstimationStatus.write(
                status.status, forMealId: status.mealId, in: cache)
        }
        for mealId in current.removedMealIds {
            if let row = try CachedMealEstimationStatus.find(mealId: mealId, in: cache) {
                cache.delete(row)
            }
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedMealEstimationStatus.self)
    }

    private let syncing = MealEstimationStatusSyncing()
}
