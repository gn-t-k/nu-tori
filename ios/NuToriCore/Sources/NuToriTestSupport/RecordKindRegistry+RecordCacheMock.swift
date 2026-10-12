public import NuToriCore

extension RecordKindRegistry where Cache == RecordCacheMock {
    /// アプリの登録簿（`AppRecordKinds.registry`）と同じ種類のメモリ版。`extra` は、テスト用の種類を足す。同じ名前の本物の種類があれば、足さずにその1行をテスト用の種類に替える（列挙にテスト用の case を足さないため）
    public static func ok(extra: [any RecordKind<RecordCacheMock>] = [])
        -> RecordKindRegistry<RecordCacheMock>
    {
        let base: [any RecordKind<RecordCacheMock>] = [
            AccountSettingsRecordKindMock(), AiUtteranceRecordKindMock(), DishRecordKindMock(),
            DishEstimationStatusRecordKindMock(), IngredientRecordKindMock(),
            MealRecordKindMock(), MealEstimationStatusRecordKindMock(), NoticeRecordKindMock(),
            SentTextRecordKindMock(), SentTextStatusRecordKindMock(),
            UsualWeighingTimeRecordKindMock(), .weightRecord, WeightTrendRecordKindMock(),
        ]
        let replaced = Set(extra.map(\.name))
        let kept = base.filter { !replaced.contains($0.name) }
        return RecordKindRegistry((kept + extra).sorted { $0.name < $1.name })
    }
}

extension RecordKind where Self == PortedRecordKind<WeightRecordSyncing, RecordCacheMock> {
    /// 体重記録の、メモリのキャッシュに当てる登録簿の1行。当て方は NuToriCore の `WeightRecordSyncing`
    public static var weightRecord: Self {
        PortedRecordKind(WeightRecordSyncing()) { $0.weightRecords }
    }
}
