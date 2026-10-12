public import NuToriCore

extension RecordKindRegistry where Cache == RecordCacheMock {
    /// アプリの登録簿（`AppRecordKinds.registry`）と同じ種類のメモリ版。当て方は NuToriCore の種類（`CacheApplying`）で、
    /// キャッシュの口だけがメモリの adapter。`extra` は、テスト用の種類を足す。
    /// 同じ名前の本物の種類があれば、足さずにその1行をテスト用の種類に替える（列挙にテスト用の case を足さないため）
    public static func ok(extra: [any RecordKind<RecordCacheMock>] = [])
        -> RecordKindRegistry<RecordCacheMock>
    {
        let base: [any RecordKind<RecordCacheMock>] = [
            PortedRecordKind(AccountSettingsSyncKind()) { $0.accountSettingsCache },
            PortedRecordKind(AiUtteranceSyncing()) { $0.aiUtteranceCache },
            PortedRecordKind(DishSyncing()) { $0.dishCache },
            PortedRecordKind(DishEstimationStatusSyncing()) { $0.dishEstimationStatusCache },
            PortedRecordKind(IngredientSyncing()) { $0.ingredientCache },
            PortedRecordKind(MealSyncing()) { $0.mealCache },
            PortedRecordKind(MealEstimationStatusSyncing()) { $0.mealEstimationStatusCache },
            PortedRecordKind(NoticeSyncing()) { $0.noticeCache },
            PortedRecordKind(SentTextSyncing()) { $0.sentTextCache },
            PortedRecordKind(SentTextStatusSyncing()) { $0.sentTextStatusCache },
            PortedRecordKind(UsualWeighingTimeSyncing()) { $0.usualWeighingTimeCache },
            PortedRecordKind(WeightRecordSyncing()) { $0.weightRecordCache },
            PortedRecordKind(WeightTrendSyncing()) { $0.weightTrendCache },
        ]
        let replaced = Set(extra.map(\.name))
        let kept = base.filter { !replaced.contains($0.name) }
        return RecordKindRegistry((kept + extra).sorted { $0.name < $1.name })
    }
}
