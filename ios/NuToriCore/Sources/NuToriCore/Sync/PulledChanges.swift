public struct PulledChanges: Sendable, Equatable {
    public let records: [WeightRecord]
    /// 記録と同じ保存で書く。通し番号だけが先に進んで記録が抜けないように
    public let state: SyncState

    public init(records: [WeightRecord], state: SyncState) {
        self.records = records
        self.state = state
    }
}
