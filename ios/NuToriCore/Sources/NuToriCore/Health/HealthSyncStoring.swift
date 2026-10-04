/// ヘルスケアの取り込みが読む置き場の口。進み具合は送り待ちの置き場に持ち、書くのは送り待ちの箱の `apply`（`SyncBoxResult.healthSyncState`）
public protocol HealthSyncStoring: Sendable {
    func healthSyncState() async throws -> HealthSyncState
}
