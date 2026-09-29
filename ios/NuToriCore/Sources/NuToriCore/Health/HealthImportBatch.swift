/// 置き場は、キャッシュへの記録の追加、送り待ちへの追加、アンカーの更新を、1つの保存で行う
public struct HealthImportBatch: Sendable, Equatable {
    public let records: [WeightRecord]
    public let pendingWrites: [PendingWrite]
    /// アンカーを進める。記録と別に保存すると、続きだけが先に進んで取り込みが抜ける
    public let state: HealthSyncState

    public init(records: [WeightRecord], pendingWrites: [PendingWrite], state: HealthSyncState) {
        self.records = records
        self.pendingWrites = pendingWrites
        self.state = state
    }
}
