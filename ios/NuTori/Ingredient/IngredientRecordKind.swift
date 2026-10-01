import Foundation
import NuToriAPI
import NuToriCore
import SwiftData

/// 材料の、登録簿の1行。取りに行った材料をキャッシュに当てる。
/// サーバーだけが書く種類なので、送る書き込みは持たない（`IngredientSyncing`）
nonisolated struct IngredientRecordKind: RecordKind {
    var synced: any SyncedRecordKind { syncing }

    /// 今の値を書いてから、削除の印の材料を消す。親の料理がまだ無くても置く（届く順は約束しない）。
    /// 置き場に無い材料の削除の印は読み飛ばす（返し直されるため）
    func apply(_ changes: [SyncChange], to cache: ModelContext) throws {
        let current = syncing.current(from: changes)
        for ingredient in current.ingredients {
            try CachedIngredient.upsert(ingredient, in: cache)
        }
        for ingredientId in current.removedIngredientIds {
            if let row = try CachedIngredient.find(id: ingredientId, in: cache) {
                cache.delete(row)
            }
        }
    }

    func erase(_ cache: ModelContext) throws {
        try cache.delete(model: CachedIngredient.self)
    }

    private let syncing = IngredientSyncing()
}
