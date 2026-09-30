public import NuToriCore

extension RecordKindRegistry where Cache == MemoryRecordCache {
    /// アプリの登録簿（`AppRecordKinds.registry`）と同じ種類のメモリ版。`extra` は、テスト用の種類を足す
    public static func memory(extra: [any RecordKind<MemoryRecordCache>] = [])
        -> RecordKindRegistry<MemoryRecordCache>
    {
        let base: [any RecordKind<MemoryRecordCache>] = [
            MemoryAccountSettingsKind(), MemoryWeightRecordKind(),
        ]
        return RecordKindRegistry((base + extra).sorted { $0.name < $1.name })
    }
}
