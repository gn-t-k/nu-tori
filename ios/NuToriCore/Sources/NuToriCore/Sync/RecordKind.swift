public import NuToriAPI

/// 記録の種類の入口。登録簿に1行ずつ足す。`Cache` は箱が持つキャッシュの型（アプリでは `ModelContext`）
public protocol RecordKind<Cache>: SyncedRecordKind {
    associatedtype Cache

    /// 取りに行った変更と今の値を、キャッシュに当てる。保存は箱が行う
    func apply(_ changes: [SyncChange], to cache: Cache) throws

    /// この種類のキャッシュを空にする（全消去）。保存は箱が行う
    func erase(_ cache: Cache) throws
}
