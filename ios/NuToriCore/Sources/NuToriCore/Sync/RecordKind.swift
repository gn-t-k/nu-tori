public import NuToriAPI

/// 記録の種類の入口。登録簿に1行ずつ足す。`Cache` は箱が持つキャッシュの型（アプリでは `ModelContext`）
public protocol RecordKind<Cache>: Sendable {
    associatedtype Cache

    /// キャッシュの型に依らない部分（名前、変更の見分け方、送る書き込み、受け付けなかったときの扱い）。同期の働きが見る
    var synced: any SyncedRecordKind { get }

    /// 取りに行った変更と今の値を、キャッシュに当てる。保存は箱が行う
    func apply(_ changes: [SyncChange], to cache: Cache) throws

    /// この種類のキャッシュを空にする（全消去）。保存は箱が行う
    func erase(_ cache: Cache) throws
}

extension RecordKind {
    /// 登録簿の名前
    public var name: RecordKindName { synced.name }
}
