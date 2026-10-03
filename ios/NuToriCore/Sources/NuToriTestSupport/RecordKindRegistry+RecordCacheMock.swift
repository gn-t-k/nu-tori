public import NuToriCore

extension RecordKindRegistry where Cache == RecordCacheMock {
    /// アプリの登録簿（`AppRecordKinds.registry`）と同じ種類のメモリ版。`extra` は、テスト用の種類を足す。同じ名前の本物の種類があれば、足さずにその1行をテスト用の種類に替える（列挙にテスト用の case を足さないため）
    public static func ok(extra: [any RecordKind<RecordCacheMock>] = [])
        -> RecordKindRegistry<RecordCacheMock>
    {
        let base: [any RecordKind<RecordCacheMock>] = [
            AccountSettingsRecordKindMock(), DishRecordKindMock(), IngredientRecordKindMock(),
            MealRecordKindMock(), MealEstimationStatusRecordKindMock(), NoticeRecordKindMock(),
            UsualWeighingTimeRecordKindMock(), WeightRecordKindMock(), WeightTrendRecordKindMock(),
        ]
        let replaced = Set(extra.map(\.name))
        let kept = base.filter { !replaced.contains($0.name) }
        return RecordKindRegistry((kept + extra).sorted { $0.name < $1.name })
    }
}
