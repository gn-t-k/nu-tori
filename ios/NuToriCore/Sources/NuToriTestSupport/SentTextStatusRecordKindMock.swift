public import NuToriAPI
public import NuToriCore

/// 送った文章の状態の、メモリのキャッシュに当てる登録簿の1行。アプリの `SentTextStatusRecordKind` と同じ振る舞い
public struct SentTextStatusRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        for status in syncing.current(from: changes) {
            cache.write(status.status, forSentTextId: status.sentTextId)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearSentTextStatuses()
    }

    private let syncing = SentTextStatusSyncing()
}
