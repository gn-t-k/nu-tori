public import NuToriAPI
public import NuToriCore

/// 体重記録の、メモリのキャッシュに当てる登録簿の1行。アプリの `WeightRecordKind` と同じ振る舞い
public struct WeightRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        let current = syncing.current(from: changes)
        for record in current.records {
            cache.upsert(record)
        }
        for recordId in current.removedRecordIds {
            cache.remove(recordId: recordId)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearRecords()
    }

    private let syncing = WeightRecordSyncing()
}
