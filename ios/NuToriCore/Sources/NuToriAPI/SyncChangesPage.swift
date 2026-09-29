/// 取りに行った1回の応答
public struct SyncChangesPage: Sendable, Equatable {
    public let changes: [SyncChange]
    /// 続きがあるとき true。落ちるまで取りに行く
    public let hasMore: Bool
    /// 次に取りに行くときの続き
    public let nextAfterSequence: Int
    /// 使い始めた日（YYYY-MM-DD）。まだ決まっていないとき nil
    public let startedOn: String?

    public init(changes: [SyncChange], hasMore: Bool, nextAfterSequence: Int, startedOn: String?) {
        self.changes = changes
        self.hasMore = hasMore
        self.nextAfterSequence = nextAfterSequence
        self.startedOn = startedOn
    }
}
