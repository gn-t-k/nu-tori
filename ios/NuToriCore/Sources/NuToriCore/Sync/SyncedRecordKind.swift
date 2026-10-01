public import NuToriAPI

/// 記録の種類の、キャッシュの型に依らない部分。同期の働き（`SyncEngine`）が見る
public protocol SyncedRecordKind: Sendable {
    /// 登録簿の名前。送り待ちの種類の名前と同じ
    var name: RecordKindName { get }

    /// 取りに行った変更が、この種類のものか
    func owns(_ change: SyncChange) -> Bool

    /// 端末が書く種類の、送る書き込みと受け付けなかったときの扱い。
    /// サーバーだけが書く種類（推定の状態）は nil。送り待ちに入らず、受け付けられないことも無い
    var writes: (any RecordKindWrites)? { get }
}
