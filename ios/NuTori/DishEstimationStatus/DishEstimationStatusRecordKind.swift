import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 料理ごとの推定の状態の、登録簿の1行。取りに行った状態をキャッシュに当てる。
/// サーバーだけが書く種類なので、送る書き込みは持たない（`DishEstimationStatusSyncing`）
nonisolated struct DishEstimationStatusRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 届いた順に状態を書いてから、削除の印の状態を消す。料理がまだ無い状態も置く（届く順は約束しない）
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        let current = syncing.current(from: changes)
        for status in current.statuses {
            try CachedDishEstimationStatus.write(
                status.status, forDishId: status.dishId, in: cache)
        }
        for dishId in current.removedDishIds {
            if let row = try CachedDishEstimationStatus.find(dishId: dishId, in: cache) {
                cache.delete(row)
            }
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedDishEstimationStatus.self)
    }

    private let syncing = DishEstimationStatusSyncing()
}
