import NuToriCore
import SwiftData

/// 記録の種類の登録簿（アプリ）。名前の順に、手で1行ずつ書く。
/// 当て方は NuToriCore の種類（`CacheApplying`）が持ち、ここでは種類ごとに SwiftData の adapter を渡す。
/// 種類を足すときは、ここに1行足す。名前は `RecordKindName`。サーバーの種類の名前の列挙（`ServerRecordKindNames`）とそろえる（`AppRecordKindsTests` が見張る）
nonisolated enum AppRecordKinds {
    static var registry: RecordKindRegistry<ModelContext> {
        RecordKindRegistry([
            PortedRecordKind(AccountSettingsSyncKind()) {
                SwiftDataSingleRecordCache<CachedAccountSettings>(context: $0)
            },
            PortedRecordKind(AiUtteranceSyncing()) {
                SwiftDataKeyedRecordCache<CachedAiUtterance>(context: $0)
            },
            PortedRecordKind(DishSyncing()) {
                SwiftDataKeyedRecordCache<CachedDish>(context: $0)
            },
            PortedRecordKind(DishEstimationStatusSyncing()) {
                SwiftDataKeyedRecordCache<CachedDishEstimationStatus>(context: $0)
            },
            PortedRecordKind(IngredientSyncing()) {
                SwiftDataKeyedRecordCache<CachedIngredient>(context: $0)
            },
            PortedRecordKind(MealSyncing()) {
                SwiftDataKeyedRecordCache<CachedMeal>(context: $0)
            },
            PortedRecordKind(MealEstimationStatusSyncing()) {
                SwiftDataKeyedRecordCache<CachedMealEstimationStatus>(context: $0)
            },
            PortedRecordKind(NoticeSyncing()) {
                SwiftDataKeyedRecordCache<CachedNotice>(context: $0)
            },
            PortedRecordKind(SentTextSyncing()) {
                SwiftDataKeyedRecordCache<CachedSentText>(context: $0)
            },
            PortedRecordKind(SentTextStatusSyncing()) {
                SwiftDataKeyedRecordCache<CachedSentTextStatus>(context: $0)
            },
            PortedRecordKind(UsualWeighingTimeSyncing()) {
                SwiftDataSingleRecordCache<CachedUsualWeighingTime>(context: $0)
            },
            PortedRecordKind(WeightRecordSyncing()) {
                SwiftDataKeyedRecordCache<CachedWeightRecord>(context: $0)
            },
            PortedRecordKind(WeightTrendSyncing()) {
                SwiftDataWeightTrendCache(context: $0)
            },
        ])
    }
}
