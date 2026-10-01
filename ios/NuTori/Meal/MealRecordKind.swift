import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 食事の、登録簿の1行。取りに行った変更と今の値をキャッシュに当てる。
/// 送る書き込みの形と、変更の見分け方は `MealSyncing`（NuToriCore）に置く
nonisolated struct MealRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 今の値を書いてから、削除の印の食事を消す。置き場に無い食事の削除の印は読み飛ばす（返し直されるため）
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        let current = syncing.current(from: changes)
        for meal in current.meals {
            try CachedMeal.upsert(meal, in: cache)
        }
        for mealId in current.removedMealIds {
            if let row = try CachedMeal.find(id: mealId, in: cache) {
                cache.delete(row)
            }
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedMeal.self)
    }

    private let syncing = MealSyncing()
}
