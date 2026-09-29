/// 1回の読み取りで増えた分と消えた分。置き場は、次の3つを1つの保存で行う
public struct HealthImportBatch: Sendable, Equatable {
    /// キャッシュに入れる、取り込んだ記録
    public let records: [WeightRecord]
    /// records の作る書き込みと、消えた分の書き込み
    public let pendingWrites: [PendingWrite]
    /// アンカーを進める。記録と別に保存すると、続きだけが先に進んで取り込みが抜ける
    public let state: HealthSyncState

    public init(records: [WeightRecord], pendingWrites: [PendingWrite], state: HealthSyncState) {
        self.records = records
        self.pendingWrites = pendingWrites
        self.state = state
    }
}
