import NuToriCore
import SwiftData

/// 記録の種類の登録簿（アプリ）。名前の順に、手で1行ずつ書く。
/// 当て方を NuToriCore に移した種類（体重記録）は、SwiftData の adapter を渡す1行で書く。
/// 種類を足すときは、ここに1行足す。名前は `RecordKindName`。サーバーの種類の名前の列挙（`ServerRecordKindNames`）とそろえる（`AppRecordKindsTests` が見張る）
nonisolated enum AppRecordKinds {
    static var registry: RecordKindRegistry<ModelContext> {
        RecordKindRegistry([
            AccountSettingsRecordKind(),
            AiUtteranceRecordKind(),
            DishRecordKind(),
            DishEstimationStatusRecordKind(),
            IngredientRecordKind(),
            MealRecordKind(),
            MealEstimationStatusRecordKind(),
            NoticeRecordKind(),
            SentTextRecordKind(),
            SentTextStatusRecordKind(),
            UsualWeighingTimeRecordKind(),
            PortedRecordKind(WeightRecordSyncing()) {
                SwiftDataKeyedRecordCache<CachedWeightRecord>(context: $0)
            },
            WeightTrendRecordKind(),
        ])
    }
}
