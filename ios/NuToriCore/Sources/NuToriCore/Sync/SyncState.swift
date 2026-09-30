public struct SyncState: Sendable, Equatable {
    public let afterSequence: Int
    public let hasCompletedInitialPull: Bool
    /// 前に取りに行ったときに読めた種類の名前
    public let readableKinds: Set<RecordKindName>
    /// YYYY-MM-DD。サーバーで決まるまで nil
    public let startedOn: String?

    public init(
        afterSequence: Int,
        hasCompletedInitialPull: Bool,
        readableKinds: Set<RecordKindName>,
        startedOn: String?
    ) {
        self.afterSequence = afterSequence
        self.hasCompletedInitialPull = hasCompletedInitialPull
        self.readableKinds = readableKinds
        self.startedOn = startedOn
    }
}
