public import NuToriAPI

/// いつもの時刻の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct UsualWeighingTimeSyncing: SyncedRecordKind {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.usualWeighingTime

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 取りに行った変更のうち、最後に届いたいつもの時刻。届いていなければ nil（キャッシュを変えない。一度届いたら消えない）
    public func current(from changes: [SyncChange]) -> UsualWeighingTime? {
        var latest: UsualWeighingTime?
        for change in changes {
            if case .usualWeighingTime(let synced) = change {
                latest = UsualWeighingTime(id: synced.id, minuteOfDay: synced.minuteOfDay)
            }
        }
        return latest
    }
}
