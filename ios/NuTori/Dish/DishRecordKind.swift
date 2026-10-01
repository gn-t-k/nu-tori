import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 料理の、登録簿の1行。取りに行った料理をキャッシュに当てる。
/// サーバーだけが書く種類なので、送る書き込みは持たない（`DishSyncing`）
nonisolated struct DishRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 今の値を書いてから、削除の印の料理を消す。親の食事がまだ無くても置く（届く順は約束しない）。
    /// 置き場に無い料理の削除の印は読み飛ばす（返し直されるため）
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        let current = syncing.current(from: changes)
        for dish in current.dishes {
            try CachedDish.upsert(dish, in: cache)
        }
        for dishId in current.removedDishIds {
            if let row = try CachedDish.find(id: dishId, in: cache) {
                cache.delete(row)
            }
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedDish.self)
    }

    private let syncing = DishSyncing()
}
