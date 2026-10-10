public import NuToriAPI
public import NuToriCore

/// 返事の、メモリのキャッシュに当てる登録簿の1行。アプリの `AiUtteranceRecordKind` と同じ振る舞い
public struct AiUtteranceRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        for utterance in syncing.current(from: changes) {
            cache.upsert(utterance)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearAiUtterances()
    }

    private let syncing = AiUtteranceSyncing()
}
