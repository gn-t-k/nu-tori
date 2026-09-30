public import Foundation

public protocol SyncStore: Sendable {
    func weightRecord(id: UUID) async throws -> WeightRecord?

    func weightRecords() async throws -> [WeightRecord]

    /// 片方だけ残ると、送り忘れるか、無い記録を送る
    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws

    /// 古い順
    func pendingWritesOldestFirst() async throws -> [PendingWrite]

    func removePendingWrites(_ writeIds: [UUID], reverting reversions: [RecordReversion])
        async throws

    func syncState() async throws -> SyncState?
    func saveSyncState(_ state: SyncState) async throws

    func apply(_ changes: PulledChanges) async throws

    /// キャッシュの記録、送り待ち、同期の状態（通し番号、初回の取得の印、使い始めた日、ヘルスケアのアンカー）をすべて消す
    func eraseAll() async throws

    func healthSyncState() async throws -> HealthSyncState
    func saveHealthSyncState(_ state: HealthSyncState) async throws

    /// 記録と送り待ちとアンカーが分かれて残ると、送り忘れるか、同じ変化を次に取りこぼす
    func applyHealthImport(_ batch: HealthImportBatch) async throws
}
