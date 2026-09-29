public struct PulledChanges: Sendable, Equatable {
    public let records: [WeightRecord]
    /// 届いたなかでいちばん新しいもの。届かなかったとき nil
    public let accountSettings: AccountSettings?
    /// 記録と同じ保存で書く。通し番号だけが先に進んで記録が抜けないように
    public let state: SyncState

    public init(records: [WeightRecord], accountSettings: AccountSettings?, state: SyncState) {
        self.records = records
        self.accountSettings = accountSettings
        self.state = state
    }
}
