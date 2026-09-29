public protocol HealthAnchorStore: Sendable {
    /// ヘルスケアのアンカーをすべて消す。次のアカウントで、全期間分を読み直すため
    func deleteAll() async throws
}
