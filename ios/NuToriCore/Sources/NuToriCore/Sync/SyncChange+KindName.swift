public import NuToriAPI

extension SyncChange {
    /// この変更がどの記録の種類のものか。知らない種類（`.unknown`）は nil。
    /// 全部の case を並べる switch は NuToriAPI の1か所（`SyncChange.recordKind`）にあり、ここはその名前を端末の名前に引き直す。
    /// 各種類は、自分の変更かをこれと自分の名前で決め、自分の case を `if case` で取り出す
    public var kindName: RecordKindName? {
        serverKindName.flatMap { RecordKindName.byServerName[$0] }
    }
}

extension RecordKindName {
    fileprivate static let byServerName = Dictionary(
        uniqueKeysWithValues: allCases.map { ($0.serverName, $0) })
}
