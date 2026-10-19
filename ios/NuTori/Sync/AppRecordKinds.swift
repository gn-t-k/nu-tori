import NuToriCore
import SwiftData

/// 記録の種類の登録簿（アプリ）。並びは NuToriCore の `RecordKindRegistry.init(ports:)` に1回だけ書き、
/// ここでは種類ごとに SwiftData の adapter を渡す。当て方は NuToriCore の種類（`CacheApplying`）が持つ。
/// 種類を足すときは、`RecordCachePorts` と `Ports` に1つずつ足す。名前は `RecordKindName`。サーバーの種類の名前の列挙（`ServerRecordKindNames`）とそろえる（`AppRecordKindsTests` が見張る）
nonisolated enum AppRecordKinds {
    static var registry: RecordKindRegistry<ModelContext> {
        RecordKindRegistry(ports: Ports())
    }

    /// SwiftData のキャッシュの口
    nonisolated struct Ports: RecordCachePorts {
        func accountSettings(in context: ModelContext) -> AccountSettingsSyncKind.Cache {
            SwiftDataSingleRecordCache<CachedAccountSettings>(context: context)
        }

        func aiUtterance(in context: ModelContext) -> AiUtteranceSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedAiUtterance>(context: context)
        }

        func dailyGuide(in context: ModelContext) -> DailyGuideSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedDailyGuide>(context: context)
        }

        func dish(in context: ModelContext) -> DishSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedDish>(context: context)
        }

        func dishEstimationStatus(in context: ModelContext) -> DishEstimationStatusSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedDishEstimationStatus>(context: context)
        }

        func expenditureEstimate(in context: ModelContext) -> ExpenditureEstimateSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedExpenditureEstimate>(context: context)
        }

        func goal(in context: ModelContext) -> GoalSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedGoal>(context: context)
        }

        func ingredient(in context: ModelContext) -> IngredientSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedIngredient>(context: context)
        }

        func meal(in context: ModelContext) -> MealSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedMeal>(context: context)
        }

        func mealEstimationStatus(in context: ModelContext) -> MealEstimationStatusSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedMealEstimationStatus>(context: context)
        }

        func notice(in context: ModelContext) -> NoticeSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedNotice>(context: context)
        }

        func sentText(in context: ModelContext) -> SentTextSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedSentText>(context: context)
        }

        func sentTextStatus(in context: ModelContext) -> SentTextStatusSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedSentTextStatus>(context: context)
        }

        func usualWeighingTime(in context: ModelContext) -> UsualWeighingTimeSyncing.Cache {
            SwiftDataSingleRecordCache<CachedUsualWeighingTime>(context: context)
        }

        func weeklyReview(in context: ModelContext) -> WeeklyReviewSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedWeeklyReview>(context: context)
        }

        func weightRecord(in context: ModelContext) -> WeightRecordSyncing.Cache {
            SwiftDataKeyedRecordCache<CachedWeightRecord>(context: context)
        }

        func weightTrend(in context: ModelContext) -> WeightTrendSyncing.Cache {
            SwiftDataWeightTrendCache(context: context)
        }
    }
}
