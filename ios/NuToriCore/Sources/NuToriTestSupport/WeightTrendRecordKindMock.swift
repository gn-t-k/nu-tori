public import NuToriAPI
public import NuToriCore

/// 体重の傾向の、メモリのキャッシュに当てる登録簿の1行。アプリの `WeightTrendRecordKind` と同じ振る舞い
public struct WeightTrendRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        switch syncing.update(from: changes) {
        case .replace(let trend): cache.setWeightTrend(trend)
        case .clear: cache.setWeightTrend(nil)
        case nil: break
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.setWeightTrend(nil)
    }

    private let syncing = WeightTrendSyncing()
}
