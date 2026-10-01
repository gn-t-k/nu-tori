import SwiftData

/// キャッシュの置き場のモデル。サーバーの写しなので移行を持たない。形が合わなければ置き場ごと消して取り直す（ADR-0022）
nonisolated enum CacheStoreSchema {
    static var schema: Schema {
        Schema([
            CachedWeightRecord.self, CachedAccountSettings.self, CachedMeal.self,
            CachedMealEstimationStatus.self, CachedDish.self, CachedIngredient.self,
            CachedSyncState.self, CachedHealthDishWrite.self,
        ])
    }
}
