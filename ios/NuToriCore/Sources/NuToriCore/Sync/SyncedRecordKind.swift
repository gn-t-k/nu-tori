public import NuToriAPI

/// 記録の種類の、キャッシュの型に依らない部分。同期の働き（`SyncEngine`）が見る
public protocol SyncedRecordKind: Sendable {
    /// 登録簿の名前。送り待ちの種類の名前と同じ
    var name: String { get }

    /// 取りに行った変更が、この種類のものか
    func owns(_ change: SyncChange) -> Bool

    /// 送り待ちの中身から、サーバーに送る書き込みを作る
    func syncWrite(for entry: PendingEntry) throws -> SyncWrite
}
