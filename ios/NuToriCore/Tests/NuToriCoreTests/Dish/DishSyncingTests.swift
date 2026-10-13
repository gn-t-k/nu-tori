import Foundation
import NuToriAPI
import NuToriCore
import Testing

@Suite("料理の同期")
struct DishSyncingTests {
    static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
    static let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!

    let syncing = DishSyncing()

    @Test("料理と料理の削除の印だけを、この種類の変更として見分けること")
    func ownsOnlyDishChanges() {
        #expect(syncing.owns(.dish(Self.synced)))
        #expect(syncing.owns(.dishDeletion(dishId: Self.dishId)))
        #expect(!syncing.owns(.ingredientDeletion(ingredientId: Self.dishId)))
        #expect(!syncing.owns(.unknown(kind: "dish")))
    }

    @Test("端末も書く種類として、送る書き込みを持つこと")
    func hasWrites() {
        #expect(syncing.writes != nil)
    }

    @Test("量の無い料理は、量を持たないこと")
    func keepsNoQuantity() throws {
        let dish = try #require(
            syncing.current(from: [
                .dish(
                    SyncedDish(
                        id: Self.dishId, mealId: Self.mealId, name: "味噌汁", quantity: nil,
                        positionInMeal: 3, version: 1))
            ]).dishes.first)

        #expect(dish.quantity == nil)
    }

    @Test("料理の名前・量と単位と出どころ・並び順・版と、親の食事の ID をそのまま持つこと")
    func keepsFields() throws {
        let dish = try #require(syncing.current(from: [.dish(Self.synced)]).dishes.first)

        #expect(dish.id == Self.dishId)
        #expect(dish.mealId == Self.mealId)
        #expect(dish.name == "親子丼")
        #expect(dish.quantity == Dish.Quantity(value: 1.5, unit: "杯", source: .corrected))
        #expect(dish.positionInMeal == 2)
        #expect(dish.version == 1)
    }

    @Test("削除の印の料理の ID を、届いた順に返すこと")
    func returnsRemovedIds() {
        let other = UUID()

        let current = syncing.current(from: [
            .dishDeletion(dishId: Self.dishId), .dishDeletion(dishId: other),
        ])

        #expect(current.removedDishIds == [Self.dishId, other])
    }

    @Suite("取りに行った変更をキャッシュに当てるとき")
    struct Applying {
        let syncing = DishSyncing()
        let cache: MemoryKeyedRecordCache<Dish, UUID>
        let kept: Dish
        let removed: Dish

        init() throws {
            (cache, kept, removed) = try Self.appliedCache()
        }

        /// 料理を2件当てたキャッシュ。親の食事は届いていない
        static func appliedCache() throws -> (
            cache: MemoryKeyedRecordCache<Dish, UUID>, kept: Dish, removed: Dish
        ) {
            let cache = MemoryKeyedRecordCache<Dish, UUID>(id: \.id)
            let kept = Dish.fixture(name: "親子丼")
            let removed = Dish.fixture(name: "味噌汁", quantity: nil, positionInMeal: 1)
            try DishSyncing().apply([kept, removed].map { .dish(synced($0)) }, to: cache)
            return (cache, kept, removed)
        }

        static func synced(_ dish: Dish) -> SyncedDish {
            SyncedDish(
                id: dish.id, mealId: dish.mealId, name: dish.name,
                quantity: dish.quantity.map {
                    .init(
                        value: $0.value, unit: $0.unit,
                        source: $0.source == .corrected ? .corrected : .estimated)
                },
                positionInMeal: dish.positionInMeal, version: dish.version)
        }

        @Test("親の食事が無くても、届いた料理が今の値でキャッシュに入ること")
        func storesArrivedDishes() {
            #expect(Set(cache.all()) == [kept, removed])
        }

        @Suite("同じ料理の新しい版が届いたとき")
        struct NewerVersionArrived {
            let syncing = DishSyncing()
            let cache: MemoryKeyedRecordCache<Dish, UUID>
            let removed: Dish
            let newer: Dish

            init() throws {
                let applied = try Applying.appliedCache()
                cache = applied.cache
                removed = applied.removed
                newer = Dish.fixture(
                    id: applied.kept.id, mealId: applied.kept.mealId, name: "カツ丼",
                    quantity: Dish.Quantity(value: 1.5, unit: "杯", source: .corrected),
                    version: 2)
            }

            @Test("キャッシュの料理を上書きすること")
            func overwritesDish() throws {
                try syncing.apply([.dish(Applying.synced(newer))], to: cache)

                #expect(Set(cache.all()) == [newer, removed])
            }
        }

        @Test("削除の印の料理が消え、キャッシュに無い料理の削除の印は読み飛ばすこと")
        func removesMarkedDishesAndSkipsMissing() throws {
            try syncing.apply(
                [.dishDeletion(dishId: removed.id), .dishDeletion(dishId: UUID())], to: cache)

            #expect(cache.all() == [kept])
        }

        @Test("同じ料理の今の値と削除の印が一緒に届いたら、消えていること")
        func removalWinsOverValueInSameChanges() throws {
            try syncing.apply(
                [.dishDeletion(dishId: kept.id), .dish(Self.synced(kept))], to: cache)

            #expect(cache.all() == [removed])
        }

        @Test("ほかの種類の変更は、キャッシュを変えないこと")
        func skipsOtherKinds() throws {
            try syncing.apply([.dishEstimationStatusDeletion(dishId: kept.id)], to: cache)

            #expect(cache.all().count == 2)
        }

        @Test("空にすると、料理がキャッシュから無くなること")
        func erases() throws {
            try syncing.erase(cache)

            #expect(cache.all().isEmpty)
        }
    }

    static let synced = SyncedDish(
        id: dishId, mealId: mealId, name: "親子丼",
        quantity: .init(value: 1.5, unit: "杯", source: .corrected), positionInMeal: 2, version: 1)
}
