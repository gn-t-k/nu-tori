public import NuToriAPI

/// 返事の同期の形。サーバーだけが書く種類なので、送り待ちに入らず、送る書き込みを持たない
public struct AiUtteranceSyncing: SyncedRecordKind {
    /// 登録簿の名前。送り待ちには入らないが、読めた種類として同期の状態に保存する
    public static let kindName = RecordKindName.aiUtterance

    public var name: RecordKindName { Self.kindName }

    public var writes: (any RecordKindWrites)? { nil }

    public init() {}

    public func owns(_ change: SyncChange) -> Bool {
        change.kindName == name
    }

    /// 取りに行った変更を、今の値の並び（届いた順）にする。送った文章より先に届いた返事も返す（届く順は約束しない）
    public func current(from changes: [SyncChange]) -> [AiUtterance] {
        changes.compactMap { change in
            guard case .aiUtterance(let synced) = change else { return nil }
            return AiUtterance(
                id: synced.id, body: synced.body, sentTextId: synced.sentTextId,
                mealIds: synced.mealIds)
        }
    }
}
