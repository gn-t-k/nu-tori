public import NuToriAPI
public import NuToriCore

/// 推定の状態の、メモリのキャッシュに当てる登録簿の1行。アプリの `MealEstimationStatusRecordKind` と同じ振る舞い
public struct MealEstimationStatusRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        let current = syncing.current(from: changes)
        for status in current.statuses {
            cache.write(status.status, forMealId: status.mealId)
        }
        for mealId in current.removedMealIds {
            cache.removeEstimationStatus(forMealId: mealId)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearEstimationStatuses()
    }

    private let syncing = MealEstimationStatusSyncing()
}
