/// 記録の種類の登録簿。名前の順に、手で1行ずつ書く。無い種類は今の道で当てる
public struct RecordKindRegistry<Cache>: Sendable {
    public let kinds: [any RecordKind<Cache>]

    public init(_ kinds: [any RecordKind<Cache>]) {
        let names = kinds.map(\.name)
        precondition(
            names == names.sorted() && Set(names).count == names.count, "登録簿は名前の順で、名前は重ならない")
        self.kinds = kinds
    }

    public func kind(named name: String) -> (any RecordKind<Cache>)? {
        kinds.first { $0.name == name }
    }

    /// 同期の働きに見せる形
    public var synced: [any SyncedRecordKind] {
        kinds.map { $0 as any SyncedRecordKind }
    }
}
