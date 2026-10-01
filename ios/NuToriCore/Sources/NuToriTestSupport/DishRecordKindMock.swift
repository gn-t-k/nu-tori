public import NuToriAPI
public import NuToriCore

/// 料理の、メモリのキャッシュに当てる登録簿の1行。アプリの `DishRecordKind` と同じ振る舞い
public struct DishRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        let current = syncing.current(from: changes)
        for dish in current.dishes {
            cache.upsert(dish)
        }
        for dishId in current.removedDishIds {
            cache.remove(dishId: dishId)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearDishes()
    }

    private let syncing = DishSyncing()
}
