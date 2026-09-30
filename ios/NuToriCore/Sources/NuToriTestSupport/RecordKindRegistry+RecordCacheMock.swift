public import NuToriCore

extension RecordKindRegistry where Cache == RecordCacheMock {
    /// アプリの登録簿（`AppRecordKinds.registry`）と同じ種類のメモリ版。`extra` は、テスト用の種類を足す
    public static func ok(extra: [any RecordKind<RecordCacheMock>] = [])
        -> RecordKindRegistry<RecordCacheMock>
    {
        let base: [any RecordKind<RecordCacheMock>] = [
            AccountSettingsRecordKindMock(), WeightRecordKindMock(),
        ]
        return RecordKindRegistry((base + extra).sorted { $0.name < $1.name })
    }
}
