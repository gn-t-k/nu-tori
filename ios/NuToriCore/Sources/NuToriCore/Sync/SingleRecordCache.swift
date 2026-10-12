/// 1件だけの記録（アカウントの設定、いつもの時刻、体重の傾向）のキャッシュの口（port）。`KeyedRecordCache` の、ID を持たない形。
/// adapter はメモリ（`MemorySingleRecordCache`）と、アプリの SwiftData。保存は箱が行う
public protocol SingleRecordCache<Record> {
    associatedtype Record

    /// まだ届いていなければ nil
    func read() throws -> Record?

    func write(_ record: Record) throws

    func clear() throws
}
