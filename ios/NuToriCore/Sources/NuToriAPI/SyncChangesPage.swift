public struct SyncChangesPage: Sendable, Equatable {
    public let changes: [SyncChange]
    public let hasMore: Bool
    public let nextAfterSequence: Int
    /// YYYY-MM-DD。使い始めた日がまだ決まっていないとき nil
    public let startedOn: String?

    public init(changes: [SyncChange], hasMore: Bool, nextAfterSequence: Int, startedOn: String?) {
        self.changes = changes
        self.hasMore = hasMore
        self.nextAfterSequence = nextAfterSequence
        self.startedOn = startedOn
    }
}
