/// 1回の読み取りで増えた分と消えた分。置き場は、次の3つを1つの保存で行う
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
