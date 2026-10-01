public import NuToriAPI
public import NuToriCore

/// 材料の、メモリのキャッシュに当てる登録簿の1行。アプリの `IngredientRecordKind` と同じ振る舞い
public struct IngredientRecordKindMock: RecordKind {
    public init() {}

    public var synced: any SyncedRecordKind { syncing }

    public func apply(_ changes: [SyncChange], to cache: RecordCacheMock) throws {
        let current = syncing.current(from: changes)
        for ingredient in current.ingredients {
            cache.upsert(ingredient)
        }
        for ingredientId in current.removedIngredientIds {
            cache.remove(ingredientId: ingredientId)
        }
    }

    public func erase(_ cache: RecordCacheMock) throws {
        cache.clearIngredients()
    }

    private let syncing = IngredientSyncing()
}
