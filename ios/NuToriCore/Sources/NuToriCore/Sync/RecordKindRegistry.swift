/// 記録の種類の登録簿。名前の順に、手で1行ずつ書く
public struct RecordKindRegistry<Cache>: Sendable {
    public let kinds: [any RecordKind<Cache>]

    public init(_ kinds: [any RecordKind<Cache>]) {
        let names = kinds.map(\.name)
        precondition(
            names == names.sorted() && Set(names).count == names.count, "登録簿は名前の順で、名前は重ならない")
        self.kinds = kinds
    }

    public func kind(named name: RecordKindName) -> (any RecordKind<Cache>)? {
        kinds.first { $0.name == name }
    }

    /// 種類 `Syncing` のキャッシュの口を、箱のキャッシュから取り出す。
    /// 登録簿に無い種類（テスト用の種類に替えた種類を含む）は `UnknownRecordKindError.notRegistered` を投げる
    public func port<Syncing: CacheApplying>(_ kind: Syncing.Type, in cache: Cache) throws
        -> Syncing.Cache
    {
        for registered in kinds {
            if let ported = registered as? PortedRecordKind<Syncing, Cache> {
                return ported.cache(in: cache)
            }
        }
        throw UnknownRecordKindError.notRegistered(Syncing.kindName)
    }

    /// 登録簿の名前の集合。今読める種類として、前に取りに行ったときの集合と比べる
    public var names: Set<RecordKindName> {
        Set(kinds.map(\.name))
    }

    /// 同期の働きに見せる形
    public var synced: [any SyncedRecordKind] {
        kinds.map(\.synced)
    }
}
