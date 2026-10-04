public import NuToriCore

/// 体重記録とアカウントの設定を持つ、メモリの置き場（同期の働きの単体テスト用）
extension SyncBoxMock where Cache == RecordCacheMock {
    /// 体重記録とアカウントの設定を持つ、成功する置き場。`recordKinds` は、テスト用の種類を足す
    public static func ok(
        records: [WeightRecord] = [],
        accountSettings: AccountSettings? = nil,
        pendingWrites: [PendingWeightRecordWrite] = [],
        pendingEntries: [PendingEntry] = [],
        recordKinds: [any RecordKind<RecordCacheMock>] = [],
        state: SyncState? = nil,
        healthState: HealthSyncState = .initial
    ) throws -> SyncBoxMock<RecordCacheMock> {
        let cache = RecordCacheMock()
        for record in records {
            cache.upsert(record)
        }
        if let accountSettings {
            cache.write(accountSettings)
        }
        return SyncBoxMock(
            kinds: .ok(extra: recordKinds), cache: cache,
            pendingEntries: try pendingWrites.map { try $0.entry() } + pendingEntries,
            state: state, healthState: healthState)
    }

    /// 失敗する置き場。`writesOnly` なら、書くときだけ失敗する
    public static func error(
        _ error: any Error,
        records: [WeightRecord] = [],
        writesOnly: Bool = false
    ) -> SyncBoxMock<RecordCacheMock> {
        let cache = RecordCacheMock()
        for record in records {
            cache.upsert(record)
        }
        return SyncBoxMock(
            kinds: .ok(), cache: cache,
            failure: writesOnly ? nil : error, writeFailure: writesOnly ? error : nil)
    }
}
