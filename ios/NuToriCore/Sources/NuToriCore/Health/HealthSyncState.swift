/// 端末に置く、ヘルスケアとの同期の進み具合。アカウントの記録とは別に、アカウントを切り替えたら消す
public struct HealthSyncState: Sendable, Equatable {
    /// 次の読み取りの続き。まだ読んでいなければ nil（最初は全期間を読む）
    public let anchor: HealthAnchor?
    public let hasWrittenCachedManualRecords: Bool

    public init(anchor: HealthAnchor?, hasWrittenCachedManualRecords: Bool) {
        self.anchor = anchor
        self.hasWrittenCachedManualRecords = hasWrittenCachedManualRecords
    }

    public static let initial = HealthSyncState(anchor: nil, hasWrittenCachedManualRecords: false)
}
