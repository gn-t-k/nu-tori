import Foundation
import NuToriCore
import NuToriTestSupport
import Testing

extension HealthSyncEngineTests {
    @Suite("栄養をヘルスケアに書く")
    struct Nutrition {
        struct SampleError: Error {}

        static let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!
        static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!

        @Suite("推定できた食事の料理がキャッシュにあるとき")
        struct EstimatedDish {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                store = try .withEstimatedDish()
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("料理ごとに、料理の名前・食事の撮った時刻・料理の ID と版で食品の組を書くこと")
            func writesFood() async throws {
                try await engine.exportNutrition()

                let write = try #require(healthStore.nutritionWrites.first)
                #expect(healthStore.nutritionWrites.count == 1)
                #expect(write.foodName == "親子丼")
                #expect(write.syncId == Nutrition.dishId)
                #expect(write.syncVersion == 1)
                #expect(write.timeZoneName == "GMT+0900")
                #expect(write.values == [.init(nutrient: .energy, amount: 200)])
            }

            @Test("書いた版を控えること")
            func remembersWrittenVersion() async throws {
                try await engine.exportNutrition()

                #expect(store.healthDishWrites == [Nutrition.dishId: 1])
            }
        }

        @Suite("推定できた食事の料理を書いたあと")
        struct AfterWritten {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: try .withEstimatedDish())
                try await engine.exportNutrition()
            }

            @Test("もう一度呼んでも、書いた料理を書き直さないこと")
            func doesNotRewrite() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.count == 1)
            }
        }

        @Suite("書いたあとに料理の版が上がったとき")
        struct NewerVersion {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                store = try .withEstimatedDish()
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
                try await engine.exportNutrition()
                store.cache.putDish(version: 2, energyKcal: 250)
            }

            @Test("書き直して、上がった版を控えること")
            func rewrites() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.map(\.syncVersion) == [1, 2])
                #expect(store.healthDishWrites == [Nutrition.dishId: 2])
            }
        }

        @Suite("書いたあとに食事と料理が無くなったとき")
        struct DishGone {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                store = try .withEstimatedDish()
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
                try await engine.exportNutrition()
                store.cache.remove(dishId: Nutrition.dishId)
            }

            @Test("ヘルスケアから消して、控えも消すこと")
            func deletes() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionDeletions == [Nutrition.dishId])
                #expect(store.healthDishWrites.isEmpty)
            }
        }

        @Suite("書いたあとにこの端末で食事を消して、料理が残っているとき")
        struct MealGone {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                store = try .withEstimatedDish()
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
                try await engine.exportNutrition()
                store.cache.remove(mealId: Nutrition.mealId)
            }

            @Test("ヘルスケアから消して、控えも消すこと")
            func deletes() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionDeletions == [Nutrition.dishId])
                #expect(store.healthDishWrites.isEmpty)
            }
        }

        @Suite("エネルギーだけを許可されて書いたあと、許可された種類が増えたとき")
        struct AuthorizedNutrientsGrew {
            let firstHealthStore: HealthStoreMock
            let secondHealthStore: HealthStoreMock
            let secondEngine: HealthSyncEngine

            init() async throws {
                let store = try SyncBoxMock<RecordCacheMock>.ok()
                try store.cache.putMeal()
                store.cache.putDish(version: 1, energyKcal: 200, proteinG: 10)
                firstHealthStore = .ok(authorizedNutrients: [.energy])
                try await HealthSyncEngine.fixture(healthStore: firstHealthStore, store: store)
                    .exportNutrition()
                secondHealthStore = .ok()
                secondEngine = .fixture(healthStore: secondHealthStore, store: store)
            }

            @Test("書いた料理を書き直さないこと")
            func doesNotRewriteWrittenDish() async throws {
                try await secondEngine.exportNutrition()

                #expect(
                    firstHealthStore.nutritionWrites.map(\.values) == [
                        [.init(nutrient: .energy, amount: 200)]
                    ])
                #expect(secondHealthStore.nutritionWrites.isEmpty)
            }
        }

        @Suite("許可された種類が増えたあとに、次の料理が届いたとき")
        struct NextDishAfterAuthorizedNutrientsGrew {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                let store = try SyncBoxMock<RecordCacheMock>.ok()
                try store.cache.putMeal()
                store.cache.putDish(version: 1, energyKcal: 200, proteinG: 10)
                try await HealthSyncEngine.fixture(
                    healthStore: .ok(authorizedNutrients: [.energy]), store: store
                ).exportNutrition()
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
                try await engine.exportNutrition()
                let soupId = UUID()
                store.cache.upsert(
                    Dish.fixture(
                        id: soupId, mealId: Nutrition.mealId, name: "味噌汁", positionInMeal: 1))
                store.cache.upsert(
                    Ingredient.fixture(dishId: soupId, nutrients: [.energyKcal: 50, .proteinG: 4]))
            }

            @Test("増えた種類を入れて書くこと")
            func includesGrownNutrients() async throws {
                try await engine.exportNutrition()

                #expect(
                    healthStore.nutritionWrites.map(\.values) == [
                        [
                            .init(nutrient: .energy, amount: 50),
                            .init(nutrient: .protein, amount: 4),
                        ]
                    ])
            }
        }

        @Suite("書き込みを許可された種類が無いとき")
        struct NothingAuthorized {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                store = try .withEstimatedDish()
                healthStore = .ok(authorizedNutrients: [])
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書かず、控えも残さないこと")
            func writesNothing() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.isEmpty)
                #expect(store.healthDishWrites.isEmpty)
            }
        }

        @Suite("許可された種類が無くて書かなかったあと、許可を得たとき")
        struct GrantedAfterNothingAuthorized {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                let store = try SyncBoxMock<RecordCacheMock>.withEstimatedDish()
                try await HealthSyncEngine.fixture(
                    healthStore: .ok(authorizedNutrients: []), store: store
                ).exportNutrition()
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("キャッシュの料理をまとめて書くこと")
            func writesCachedDishes() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.count == 1)
            }
        }

        @Suite("食事がまだ届いていない料理があるとき")
        struct MealNotArrivedYet {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                let store = try SyncBoxMock<RecordCacheMock>.ok()
                store.cache.write(.estimated, forMealId: Nutrition.mealId)
                store.cache.putDish(version: 1, energyKcal: 200)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書かないこと")
            func writesNothing() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.isEmpty)
            }
        }

        @Suite("食事がまだ届いていなくて書かなかった料理の、食事が届いたとき")
        struct MealArrivedLater {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() async throws {
                let store = try SyncBoxMock<RecordCacheMock>.ok()
                store.cache.write(.estimated, forMealId: Nutrition.mealId)
                store.cache.putDish(version: 1, energyKcal: 200)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
                try await engine.exportNutrition()
                try store.cache.putMeal()
            }

            @Test("書くこと")
            func writes() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.count == 1)
            }
        }

        @Suite("書く値が1つも無い料理があるとき")
        struct DishWithoutValues {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                try store.cache.putMeal()
                store.cache.upsert(Dish.fixture(id: Nutrition.dishId, mealId: Nutrition.mealId))
                store.cache.upsert(Ingredient.fixture(dishId: Nutrition.dishId, nutrients: [:]))
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書かず、控えも残さないこと")
            func writesNothing() async throws {
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.isEmpty)
                #expect(store.healthDishWrites.isEmpty)
            }
        }

        @Suite("初めて食事を記録したあと、まだ許可を求めていないとき")
        struct AfterFirstMealNotYetRequested {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok(nutritionRequestStatus: .notYetRequested)
                engine = .fixture(healthStore: healthStore, store: try .withEstimatedDish())
            }

            @Test("許可を求め、許可の画面が閉じたあとにキャッシュの料理を書くこと")
            func requestsThenWrites() async throws {
                try await engine.requestNutritionAuthorizationAfterMealRecorded()

                #expect(healthStore.nutritionAuthorizationRequests == 1)
                #expect(healthStore.nutritionWrites.count == 1)
            }
        }

        @Suite("初めて食事を記録したあと、許可を求め済みのとき")
        struct AfterFirstMealAlreadyRequested {
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                healthStore = .ok(nutritionRequestStatus: .alreadyRequested)
                engine = .fixture(healthStore: healthStore, store: try .withEstimatedDish())
            }

            @Test("求めず、書きもしないこと")
            func doesNothing() async throws {
                try await engine.requestNutritionAuthorizationAfterMealRecorded()

                #expect(healthStore.nutritionAuthorizationRequests == 0)
                #expect(healthStore.nutritionWrites.isEmpty)
            }
        }

        @Suite("ヘルスケアに書けないとき")
        struct WriteFailure {
            let store: SyncBoxMock<RecordCacheMock>
            let reporting: ErrorReportingSessionMock
            let engine: HealthSyncEngine

            init() throws {
                store = try .withTwoEstimatedDishes()
                reporting = .ok()
                engine = .fixture(
                    healthStore: .ok(nutritionFailure: SampleError()), store: store,
                    errorReporting: reporting)
            }

            @Test("栄養の書き込みの失敗として、1回だけ Sentry に送り、控えを残さないこと")
            func reportsOnce() async throws {
                await #expect(throws: SampleError.self) {
                    try await engine.exportNutrition()
                }

                #expect(reporting.reported == [.healthNutritionWrite])
                #expect(store.healthDishWrites.isEmpty)
            }
        }

        @Suite("ヘルスケアへの書き込みが時間切れになったとき")
        struct WriteTimedOut {
            let reporting: ErrorReportingSessionMock
            let engine: HealthSyncEngine

            init() throws {
                reporting = .ok()
                engine = .fixture(
                    healthStore: .ok(nutritionFailure: URLError(.timedOut)),
                    store: try .withTwoEstimatedDishes(), errorReporting: reporting)
            }

            @Test("Sentry に送らないこと")
            func doesNotReport() async throws {
                await #expect(throws: URLError.self) {
                    try await engine.exportNutrition()
                }

                #expect(reporting.reported.isEmpty)
            }
        }
    }
}

extension SyncBoxMock where Cache == RecordCacheMock {
    /// 推定できた食事に、親子丼が1つある
    static func withEstimatedDish() throws -> SyncBoxMock<RecordCacheMock> {
        let store = try SyncBoxMock<RecordCacheMock>.ok()
        try store.cache.putMeal()
        store.cache.putDish(version: 1, energyKcal: 200)
        return store
    }

    /// 推定できた食事に、親子丼と味噌汁の2つの料理がある
    fileprivate static func withTwoEstimatedDishes() throws -> SyncBoxMock<RecordCacheMock> {
        let store = try withEstimatedDish()
        store.cache.upsert(
            Dish.fixture(
                id: UUID(), mealId: HealthSyncEngineTests.Nutrition.mealId, name: "味噌汁",
                positionInMeal: 1))
        return store
    }
}

extension RecordCacheMock {
    func putMeal(status: MealEstimationStatus = .estimated) throws {
        upsert(
            try Meal.fixture(
                eatenAt: "2026-09-22T12:10:00+09:00", sentAt: "2026-09-22T12:11:00+09:00",
                id: HealthSyncEngineTests.Nutrition.mealId))
        write(status, forMealId: HealthSyncEngineTests.Nutrition.mealId)
    }

    /// 親子丼 1 つ。材料は 1 つで、量は 100 g（値はそのまま料理の合計になる）
    func putDish(version: Int, energyKcal: Double, proteinG: Double? = nil) {
        let dishId = HealthSyncEngineTests.Nutrition.dishId
        upsert(
            Dish.fixture(
                id: dishId, mealId: HealthSyncEngineTests.Nutrition.mealId, version: version))
        var nutrients: [Nutrient: Double] = [.energyKcal: energyKcal]
        if let proteinG {
            nutrients[.proteinG] = proteinG
        }
        upsert(
            Ingredient.fixture(
                id: dishId, dishId: dishId, nutrients: nutrients))
    }
}
