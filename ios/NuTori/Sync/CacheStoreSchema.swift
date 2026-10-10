import SwiftData

/// キャッシュの置き場のモデル。サーバーの写しなので移行を持たない。形が合わなければ置き場ごと消して取り直す（ADR-0022）
nonisolated enum CacheStoreSchema {
    static var schema: Schema {
        Schema([
            CachedWeightRecord.self, CachedAccountSettings.self, CachedMeal.self,
            CachedMealEstimationStatus.self, CachedDish.self, CachedDishEstimationStatus.self,
            CachedIngredient.self,
            CachedNotice.self, CachedUsualWeighingTime.self, CachedWeightTrendDay.self,
            CachedSentText.self, CachedSentTextStatus.self, CachedAiUtterance.self,
            CachedSyncState.self, CachedHealthDishWrite.self,
        ])
    }
}
