/// ID で引く記録のキャッシュの口（port）。記録の種類の当て方（`CacheApplying`）が、キャッシュの置き方を知らずに読み書きする。
/// adapter はメモリ（`MemoryKeyedRecordCache`）と、アプリの SwiftData。保存は箱が行う。
/// 親の ID で引く種類（推定の状態）は、親の ID を `ID` にする
public protocol KeyedRecordCache<Record, ID> {
    associatedtype Record
    associatedtype ID

    /// 同じ ID の記録があれば値を替え、無ければ足す
    func upsert(_ record: Record) throws

    /// キャッシュに無い ID は読み飛ばす（削除の印は返し直されるため）
    func remove(id: ID) throws

    func removeAll() throws

    /// キャッシュに無い ID は nil
    func record(id: ID) throws -> Record?

    /// 並びの順は約束しない
    func all() throws -> [Record]
}
