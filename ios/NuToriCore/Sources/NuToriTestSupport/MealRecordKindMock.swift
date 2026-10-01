public import NuToriAPI
public import NuToriCore

/// 食事の、メモリのキャッシュに当てる登録簿の1行。アプリの `MealRecordKind` と同じ振る舞い
public struct MealRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        let current = syncing.current(from: changes)
        for meal in current.meals {
            cache.upsert(meal)
        }
        for mealId in current.removedMealIds {
            cache.remove(mealId: mealId)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearMeals()
    }

    private let syncing = MealSyncing()
}
