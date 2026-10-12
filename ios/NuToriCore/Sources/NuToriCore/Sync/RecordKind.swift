public import NuToriAPI

/// 登録簿の1行。箱が、種類ごとの型を知らずに当てるための形。`Cache` は箱が持つキャッシュの型（アプリでは `ModelContext`）。
/// 記録の種類は `PortedRecordKind` で1行にする。じかに従うのは、当てられたことを数えるテスト用の種類だけ
public protocol RecordKind<Cache>: Sendable {
    associatedtype Cache

    /// 箱のキャッシュの型に依らない部分（名前、変更の見分け方、送る書き込み、受け付けなかったときの扱い）。同期の働きが見る
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
