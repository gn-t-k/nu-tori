import Synchronization

/// メモリの、1件だけの記録のキャッシュ。当て方の単体テストと、メモリの箱が使う
public final class MemorySingleRecordCache<Record: Sendable>: SingleRecordCache, Sendable {
    public init() {}

    public func read() -> Record? {
        record.withLock { $0 }
    }

    public func write(_ record: Record) {
        self.record.withLock { $0 = record }
    }

    public func clear() {
        record.withLock { $0 = nil }
    }

    private let record = Mutex<Record?>(nil)
}
