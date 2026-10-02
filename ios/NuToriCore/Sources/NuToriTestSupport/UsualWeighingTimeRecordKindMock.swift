public import NuToriAPI
public import NuToriCore

/// いつもの時刻の、メモリのキャッシュに当てる登録簿の1行。アプリの `UsualWeighingTimeRecordKind` と同じ振る舞い
public struct UsualWeighingTimeRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        if let usualWeighingTime = syncing.current(from: changes) {
            cache.setUsualWeighingTime(usualWeighingTime)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.setUsualWeighingTime(nil)
    }

    private let syncing = UsualWeighingTimeSyncing()
}
