public import Foundation

/// 箱に、今の道（登録簿に無い種類）の口を足したもの。登録簿へ種類を移すたびに、口が減っていく
public protocol SyncStore: SyncBox {
    func weightRecord(id: UUID) async throws -> WeightRecord?

    func weightRecords() async throws -> [WeightRecord]

    /// 片方だけ残ると、送り忘れるか、無い記録を送る
    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws

    func accountSettings() async throws -> AccountSettings?

    /// 片方だけ残ると、送り忘れるか、保存していない設定を送る
    func save(_ settings: AccountSettings, enqueuing write: PendingWrite) async throws

    func syncState() async throws -> SyncState?
    func saveSyncState(_ state: SyncState) async throws

    func healthSyncState() async throws -> HealthSyncState
    func saveHealthSyncState(_ state: HealthSyncState) async throws

    /// 記録と送り待ちとアンカーが分かれて残ると、送り忘れるか、同じ変化を次に取りこぼす
    func applyHealthImport(_ batch: HealthImportBatch) async throws
}

extension SyncStore {
    /// 古い順。登録簿に無い種類の送り待ちを読む
    public func pendingWritesOldestFirst() async throws -> [PendingWrite] {
        try await pendingEntries().map { try PendingWrite(entry: $0) }
    }

    public func removePendingWrites(_ writeIds: [UUID], reverting reversions: [RecordReversion])
        async throws
    {
        try await apply(SyncBoxResult(resolvedWriteIds: writeIds, reversions: reversions))
    }

    public func apply(_ changes: PulledChanges) async throws {
        try await apply(SyncBoxResult(pulled: changes))
    }
}
