import NuToriCore
import SwiftData

/// 記録の種類の登録簿（アプリ）。名前の順に、手で1行ずつ書く。
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
            WeightRecordKind(),
            WeightTrendRecordKind(),
        ])
    }
}
