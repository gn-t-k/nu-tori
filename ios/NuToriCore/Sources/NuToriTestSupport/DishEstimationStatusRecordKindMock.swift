public import NuToriAPI
public import NuToriCore

/// 料理ごとの推定の状態の、メモリのキャッシュに当てる登録簿の1行。アプリの `DishEstimationStatusRecordKind` と同じ振る舞い
public struct DishEstimationStatusRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        let current = syncing.current(from: changes)
        for status in current.statuses {
            cache.write(status.status, forDishId: status.dishId)
        }
        for dishId in current.removedDishIds {
            cache.removeEstimationStatus(forDishId: dishId)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearDishEstimationStatuses()
    }

    private let syncing = DishEstimationStatusSyncing()
}
