public import NuToriAPI

/// 1つの種類に当てる変更。
/// 種類の名前と変更を別々に受け取らず、変更の `kindName` から組むので、ほかの種類の変更が混ざらない
public struct KindChanges: Sendable, Equatable {
    public let kind: RecordKindName
    public let changes: [SyncChange]

    private init(kind: RecordKindName, changes: [SyncChange]) {
        self.kind = kind
        self.changes = changes
    }

    /// 続けて並ぶ同じ種類の変更を1つにまとめる。並びは変えない。
    /// 知らない種類の変更（`kindName` が nil）は読み飛ばし、空の種類は作らない
    public static func grouping(_ changes: [SyncChange]) -> [KindChanges] {
        var groups: [KindChanges] = []
        for change in changes {
            guard let kind = change.kindName else { continue }
            if let last = groups.last, last.kind == kind {
                groups[groups.count - 1] = KindChanges(kind: kind, changes: last.changes + [change])
            } else {
                groups.append(KindChanges(kind: kind, changes: [change]))
            }
        }
        return groups
    }

    /// その種類の変更だけを、並びを変えずに取り出す。1つも無ければ変更が空のものを返す
    public static func owned(by name: RecordKindName, in changes: [SyncChange]) -> KindChanges {
        KindChanges(kind: name, changes: changes.filter { $0.kindName == name })
    }
}
