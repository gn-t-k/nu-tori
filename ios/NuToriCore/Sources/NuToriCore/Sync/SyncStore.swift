public import Foundation

public protocol SyncStore: Sendable {
    func weightRecord(id: UUID) async throws -> WeightRecord?

    func weightRecords() async throws -> [WeightRecord]

    /// 記録の保存と送り待ちへの追加は、1つの保存で行う
    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws

    /// 古い順
    func pendingWrites() async throws -> [PendingWrite]

    func removePendingWrites(_ writeIds: [UUID], reverting reversions: [RecordReversion])
        async throws

    func syncState() async throws -> SyncState?
    func saveSyncState(_ state: SyncState) async throws

    func apply(_ changes: PulledChanges) async throws

    func healthSyncState() async throws -> HealthSyncState
    func saveHealthSyncState(_ state: HealthSyncState) async throws

    /// 記録のキャッシュへの追加と、送り待ちへの追加と、アンカーの更新は、1つの保存で行う
    func applyHealthImport(_ batch: HealthImportBatch) async throws
}
