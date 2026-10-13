import Synchronization

/// メモリの、ID で引く記録のキャッシュ。当て方の単体テストと、メモリの箱が使う
public final class MemoryKeyedRecordCache<Record: Sendable, ID: Hashable & Sendable>:
    KeyedRecordCache, Sendable
{
    /// - Parameter id: 記録から ID を取り出す
    public init(id: @escaping @Sendable (Record) -> ID) {
        self.id = id
    }

    public func upsert(_ record: Record) {
        records.withLock { $0[id(record)] = record }
    }

    public func remove(id: ID) {
        records.withLock { $0[id] = nil }
    }

    public func removeAll() {
        records.withLock { $0 = [:] }
    }

    public func all() -> [Record] {
        records.withLock { Array($0.values) }
    }

    private let id: @Sendable (Record) -> ID
    private let records = Mutex<[ID: Record]>([:])
}
