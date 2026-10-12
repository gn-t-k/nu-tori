import SwiftData

/// `SwiftDataKeyedRecordCache` が読み書きする、キャッシュの行。記録の種類ごとに、`@Model` の行をこれに従わせる
nonisolated protocol KeyedCacheRow: PersistentModel {
    associatedtype Record
    /// 行を引く ID。`PersistentModel` の `ID`（`PersistentIdentifier`）とは別のもの
    associatedtype RecordID

    init(_ record: Record) throws

    static func id(of record: Record) -> RecordID

    /// `#Predicate` は行の型ごとに書くので、引き方は行が持つ
    static func find(id: RecordID, in context: ModelContext) throws -> Self?

    func apply(_ record: Record) throws

    /// 読めない行は nil
    func record() -> Record?
}
