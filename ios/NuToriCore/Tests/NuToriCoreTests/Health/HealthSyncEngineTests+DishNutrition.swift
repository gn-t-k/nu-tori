import Foundation
import NuToriCore
import NuToriTestSupport
import Testing

extension HealthSyncEngineTests {
    @Suite("ヘルスケアの料理ごとの判断")
    struct DishNutrition {
        static let mealId = HealthSyncEngineTests.Nutrition.mealId
        static let dishId = HealthSyncEngineTests.Nutrition.dishId

        @Suite("推定し直しをしていない料理（料理ごとの推定の状態が無い）のとき")
        struct WithoutDishStatus {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                let store = try SyncBoxMock<RecordCacheMock>.withEstimatedDish()
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書くこと")
            func exports() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.map(\.syncId) == [DishNutrition.dishId])
            }
        }

        @Suite("料理ごとの推定の状態が推定できたとき")
        struct DishEstimated {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                let store = try SyncBoxMock<RecordCacheMock>.withEstimatedDish()
                store.cache.write(.estimated, forDishId: DishNutrition.dishId)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書くこと")
            func exports() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.map(\.syncId) == [DishNutrition.dishId])
            }
        }

        @Suite("料理ごとの推定の状態が推定中のとき")
        struct DishEstimating {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                let store = try SyncBoxMock<RecordCacheMock>.withEstimatedDish()
                store.cache.write(.estimating, forDishId: DishNutrition.dishId)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書かないこと")
            func doesNotExport() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.isEmpty)
            }
        }

        @Suite("料理ごとの推定の状態が翌日に推定のとき")
        struct DishDeferredToNextDay {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                let store = try SyncBoxMock<RecordCacheMock>.withEstimatedDish()
                store.cache.write(.deferredToNextDay, forDishId: DishNutrition.dishId)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書かないこと")
            func doesNotExport() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.isEmpty)
            }
        }

        @Suite("料理なし食事に足した料理の推定し直しが通ったとき")
        struct DishAddedToMealWithoutDishes {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                let store = try SyncBoxMock<RecordCacheMock>.ok()
                try store.cache.putMeal(status: .noDishes)
                store.cache.putDish(version: 2, energyKcal: 200)
                store.cache.write(.estimated, forDishId: DishNutrition.dishId)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("食事の推定の状態は見ずに書くこと")
            func exports() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.map(\.syncId) == [DishNutrition.dishId])
            }
        }

        @Suite("推定できなかった食事に足した料理の推定し直しが通ったとき")
        struct DishAddedToMealFailed {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                let store = try SyncBoxMock<RecordCacheMock>.ok()
                try store.cache.putMeal(status: .failed)
                store.cache.putDish(version: 2, energyKcal: 200)
                store.cache.write(.estimated, forDishId: DishNutrition.dishId)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("食事の推定の状態は見ずに書くこと")
            func exports() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.map(\.syncId) == [DishNutrition.dishId])
            }
        }

        @Suite("量が無い料理のとき")
        struct DishWithoutQuantity {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                let store = try SyncBoxMock<RecordCacheMock>.withEstimatedDish()
                store.cache.upsert(
                    Dish.fixture(
                        id: DishNutrition.dishId, mealId: DishNutrition.mealId, quantity: nil))
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書かないこと")
            func doesNotExport() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.isEmpty)
            }
        }

        @Suite("料理なしの食事に料理を足して、推定し直しを待つとき")
        struct DishAddedToMealWithoutDishesAwaitingEstimation {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                store = try .ok()
                try store.cache.putMeal(status: .noDishes)
                // 端末で足した料理は、版 1・量なし・材料なしでキャッシュに入る
                store.cache.upsert(
                    Dish.fixture(
                        id: DishNutrition.dishId, mealId: DishNutrition.mealId, quantity: nil))
                store.cache.write(.estimating, forDishId: DishNutrition.dishId)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
                try await engine.exportNutrition()
            }

            @Test("待つあいだは書かないこと")
            func doesNotWriteWhileWaiting() {
                #expect(healthStore.nutritionWrites.isEmpty)
                #expect(store.healthDishWrites.isEmpty)
            }

            @Suite("推定し直しが通ったとき")
            struct Estimated {
                let store: SyncBoxMock<RecordCacheMock>
                let healthStore: HealthStoreMock
                let engine: HealthSyncEngine

                init() async throws {
                    let waiting = try await DishAddedToMealWithoutDishesAwaitingEstimation()
                    store = waiting.store
                    healthStore = waiting.healthStore
                    engine = waiting.engine
                    store.cache.putDish(version: 2, energyKcal: 300)
                    store.cache.write(.estimated, forDishId: DishNutrition.dishId)
                }

                @Test("書くこと")
                func exports() async throws {
                    try await engine.exportNutrition()

                    #expect(healthStore.nutritionWrites.map(\.syncVersion) == [2])
                    #expect(store.healthDishWrites == [DishNutrition.dishId: 2])
                }
            }
        }

        @Suite("書いた料理の名前を直して、推定し直しを待つとき")
        struct RenamedWrittenDish {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                store = try .withEstimatedDish()
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
                try await engine.exportNutrition()
                // 待つあいだに時刻を直して版が上がっても、前の材料は残る
                store.cache.putDish(version: 2, energyKcal: 200)
                store.cache.write(.estimating, forDishId: DishNutrition.dishId)
            }

            @Test("待つあいだは書き直さず、前に書いた栄養を残すこと")
            func keepsWrittenWhileWaiting() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.map(\.syncVersion) == [1])
                #expect(healthStore.nutritionDeletions.isEmpty)
                #expect(store.healthDishWrites == [DishNutrition.dishId: 1])
            }

            @Suite("待つあいだに書き出してから、推定し直しが通ったとき")
            struct Estimated {
                let store: SyncBoxMock<RecordCacheMock>
                let healthStore: HealthStoreMock
                let engine: HealthSyncEngine

                init() async throws {
                    let renamed = try await RenamedWrittenDish()
                    store = renamed.store
                    healthStore = renamed.healthStore
                    engine = renamed.engine
                    try await engine.exportNutrition()
                    store.cache.putDish(version: 3, energyKcal: 400)
                    store.cache.write(.estimated, forDishId: DishNutrition.dishId)
                }

                @Test("上がった版で書き直すこと")
                func rewrites() async throws {
                    try await engine.exportNutrition()

                    #expect(healthStore.nutritionWrites.map(\.syncVersion) == [1, 3])
                    #expect(store.healthDishWrites == [DishNutrition.dishId: 3])
                }
            }

            @Suite("推定し直しが通らず材料が無くなったとき")
            struct Failed {
                let store: SyncBoxMock<RecordCacheMock>
                let healthStore: HealthStoreMock
                let engine: HealthSyncEngine

                init() async throws {
                    let renamed = try await RenamedWrittenDish()
                    store = renamed.store
                    healthStore = renamed.healthStore
                    engine = renamed.engine
                    store.cache.remove(ingredientId: DishNutrition.dishId)
                    store.cache.write(.failed, forDishId: DishNutrition.dishId)
                }

                @Test("ヘルスケアから消して控えも消すこと")
                func deletes() async throws {
                    try await engine.exportNutrition()

                    #expect(healthStore.nutritionDeletions == [DishNutrition.dishId])
                    #expect(store.healthDishWrites.isEmpty)
                }
            }
        }

        @Suite("書いた料理の削除の印が届いて、料理と材料が無くなったとき")
        struct DishDeletionMarkArrived {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                store = try .withEstimatedDish()
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
                try await engine.exportNutrition()
                store.cache.remove(dishId: DishNutrition.dishId)
                store.cache.remove(ingredientId: DishNutrition.dishId)
            }

            @Test("ヘルスケアから消して、控えも消すこと")
            func deletes() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionDeletions == [DishNutrition.dishId])
                #expect(store.healthDishWrites.isEmpty)
            }
        }
    }
}
