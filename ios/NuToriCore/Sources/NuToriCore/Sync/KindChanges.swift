public import NuToriAPI

/// 1つの種類に当てる変更
public struct KindChanges: Sendable, Equatable {
    public let kind: String
    public let changes: [SyncChange]

    public init(kind: String, changes: [SyncChange]) {
        self.kind = kind
        self.changes = changes
    }
}
