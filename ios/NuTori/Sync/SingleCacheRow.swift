import SwiftData

/// `SwiftDataSingleRecordCache` が読み書きする、1件だけの記録のキャッシュの行。行は1つだけ置く
nonisolated protocol SingleCacheRow: PersistentModel {
    associatedtype Record

    init(_ record: Record) throws

    func apply(_ record: Record) throws

    /// 読めない行は nil
    func record() -> Record?
}
