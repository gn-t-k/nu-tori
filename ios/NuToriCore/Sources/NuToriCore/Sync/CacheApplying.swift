public import NuToriAPI

/// キャッシュへの当て方を持つ、記録の種類。当て方（今の値を足す・直す、消えた ID を消す、空にする）を種類ごとに1回だけここに書き、
/// メモリの adapter で単体テストする。`Cache` は、その種類が読み書きするキャッシュの口
/// （`any KeyedRecordCache<…>` か `any SingleRecordCache<…>`）
public protocol CacheApplying: SyncedRecordKind {
    associatedtype Cache

    /// 登録簿の名前。種類で読む（`RecordCacheReading.read`）ときに、登録簿に無い種類を名前で知らせる
    static var kindName: RecordKindName { get }

    /// 取りに行った変更と今の値を、キャッシュに当てる。自分の種類でない変更は読み飛ばす。保存は箱が行う
    func apply(_ changes: [SyncChange], to cache: Cache) throws

    /// この種類のキャッシュを空にする（全消去）。保存は箱が行う
    func erase(_ cache: Cache) throws
}
