public import NuToriCore

extension RecordCacheMock {
    /// メモリのキャッシュの口。種類ごとに、`RecordCacheMock` の持つメモリの adapter を渡す
    public struct Ports: RecordCachePorts {
        public init() {}

        public func accountSettings(in cache: RecordCacheMock) -> AccountSettingsSyncKind.Cache {
            cache.accountSettingsCache
        }

        public func aiUtterance(in cache: RecordCacheMock) -> AiUtteranceSyncing.Cache {
            cache.aiUtteranceCache
        }

        public func dailyGuide(in cache: RecordCacheMock) -> DailyGuideSyncing.Cache {
            cache.dailyGuideCache
        }

        public func dish(in cache: RecordCacheMock) -> DishSyncing.Cache {
            cache.dishCache
        }

        public func dishEstimationStatus(in cache: RecordCacheMock)
            -> DishEstimationStatusSyncing.Cache
        {
            cache.dishEstimationStatusCache
        }

        public func expenditureEstimate(in cache: RecordCacheMock)
            -> ExpenditureEstimateSyncing.Cache
        {
            cache.expenditureEstimateCache
        }

        public func goal(in cache: RecordCacheMock) -> GoalSyncing.Cache {
            cache.goalCache
        }

        public func ingredient(in cache: RecordCacheMock) -> IngredientSyncing.Cache {
            cache.ingredientCache
        }

        public func meal(in cache: RecordCacheMock) -> MealSyncing.Cache {
            cache.mealCache
        }

        public func mealEstimationStatus(in cache: RecordCacheMock)
            -> MealEstimationStatusSyncing.Cache
        {
            cache.mealEstimationStatusCache
        }

        public func notice(in cache: RecordCacheMock) -> NoticeSyncing.Cache {
            cache.noticeCache
        }

        public func sentText(in cache: RecordCacheMock) -> SentTextSyncing.Cache {
            cache.sentTextCache
        }

        public func sentTextStatus(in cache: RecordCacheMock) -> SentTextStatusSyncing.Cache {
            cache.sentTextStatusCache
        }

        public func subscriptionStatus(in cache: RecordCacheMock)
            -> SubscriptionStatusSyncing.Cache
        {
            cache.subscriptionStatusCache
        }

        public func usualWeighingTime(in cache: RecordCacheMock) -> UsualWeighingTimeSyncing.Cache {
            cache.usualWeighingTimeCache
        }

        public func weeklyReview(in cache: RecordCacheMock) -> WeeklyReviewSyncing.Cache {
            cache.weeklyReviewCache
        }

        public func weightRecord(in cache: RecordCacheMock) -> WeightRecordSyncing.Cache {
            cache.weightRecordCache
        }

        public func weightTrend(in cache: RecordCacheMock) -> WeightTrendSyncing.Cache {
            cache.weightTrendCache
        }
    }
}
