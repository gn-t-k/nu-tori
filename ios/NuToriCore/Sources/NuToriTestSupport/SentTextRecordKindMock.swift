public import NuToriAPI
public import NuToriCore

/// 送った文章の、メモリのキャッシュに当てる登録簿の1行。アプリの `SentTextRecordKind` と同じ振る舞い
public struct SentTextRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        let current = syncing.current(from: changes)
        for sentText in current.sentTexts {
            cache.upsert(sentText)
        }
        for sentTextId in current.removedSentTextIds {
            cache.remove(sentTextId: sentTextId)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearSentTexts()
    }

    private let syncing = SentTextSyncing()
}
