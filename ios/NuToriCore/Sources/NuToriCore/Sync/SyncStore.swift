public import Foundation

public protocol SyncStore: Sendable {
    func weightRecord(id: UUID) async throws -> WeightRecord?

    /// 片方だけ残ると、送り忘れるか、無い記録を送る
    func save(_ record: WeightRecord, enqueuing write: PendingWrite) async throws

    func accountSettings() async throws -> AccountSettings?

    /// アカウントの設定の保存と送り待ちへの追加は、1つの保存で行う
    func save(_ settings: AccountSettings, enqueuing write: PendingWrite) async throws

    func pendingWritesOldestFirst() async throws -> [PendingWrite]

    func removePendingWrites(_ writeIds: [UUID], reverting reversions: [RecordReversion])
        async throws

    func syncState() async throws -> SyncState?
    func saveSyncState(_ state: SyncState) async throws

    func apply(_ changes: PulledChanges) async throws
}
