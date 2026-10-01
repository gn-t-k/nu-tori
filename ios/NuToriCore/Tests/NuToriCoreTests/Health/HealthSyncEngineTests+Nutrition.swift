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
                store = try .ok()
                try store.cache.putMeal(estimated: true)
                store.cache.putDish(version: 1, energyKcal: 200)
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

            @Test("もう一度呼んでも、書いた料理を書き直さないこと")
            func doesNotRewrite() async throws {
                try await engine.exportNutrition()
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.count == 1)
            }

            @Test("料理の版が上がったら、書き直すこと")
            func rewritesNewerVersion() async throws {
                try await engine.exportNutrition()
                store.cache.putDish(version: 2, energyKcal: 250)
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.map(\.syncVersion) == [1, 2])
                #expect(store.healthDishWrites == [Nutrition.dishId: 2])
            }

            @Test("食事と料理が無くなったら、ヘルスケアから消して控えも消すこと")
            func deletesWhenDishIsGone() async throws {
                try await engine.exportNutrition()
                store.cache.remove(dishId: Nutrition.dishId)
                try await engine.exportNutrition()

                #expect(healthStore.nutritionDeletions == [Nutrition.dishId])
                #expect(store.healthDishWrites.isEmpty)
            }

            @Test("この端末で食事を消したら、料理が残っていても、ヘルスケアから消すこと")
            func deletesWhenMealIsGone() async throws {
                try await engine.exportNutrition()
                store.cache.remove(mealId: Nutrition.mealId)
                try await engine.exportNutrition()

                #expect(healthStore.nutritionDeletions == [Nutrition.dishId])
                #expect(store.healthDishWrites.isEmpty)
            }
        }

        @Suite("許可された種類があとから増えたとき")
        struct AuthorizedNutrientsGrew {
            let store: SyncBoxMock<RecordCacheMock>
            let firstHealthStore: HealthStoreMock
            let secondHealthStore: HealthStoreMock

            init() throws {
                store = try .ok()
                try store.cache.putMeal(estimated: true)
                store.cache.putDish(version: 1, energyKcal: 200, proteinG: 10)
                firstHealthStore = .ok(authorizedNutrients: [.energy])
                secondHealthStore = .ok()
            }

            @Test("書いた料理を書き直さず、増えた種類は次に書く料理から入れること")
            func doesNotRewriteWrittenDish() async throws {
                try await HealthSyncEngine.fixture(healthStore: firstHealthStore, store: store)
                    .exportNutrition()
                let secondEngine = HealthSyncEngine.fixture(
                    healthStore: secondHealthStore, store: store)
                try await secondEngine.exportNutrition()
                #expect(secondHealthStore.nutritionWrites.isEmpty)

                let soupId = UUID()
                store.cache.upsert(
                    Dish.fixture(
                        id: soupId, mealId: Nutrition.mealId, name: "味噌汁", positionInMeal: 1))
                store.cache.upsert(
                    Ingredient.fixture(
                        dishId: soupId, nutrients: [.energyKcal: 50, .proteinG: 4]))
                try await secondEngine.exportNutrition()

                #expect(
                    firstHealthStore.nutritionWrites.map(\.values) == [
                        [.init(nutrient: .energy, amount: 200)]
                    ])
                #expect(
                    secondHealthStore.nutritionWrites.map(\.values) == [
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

            init() throws {
                store = try .ok()
                try store.cache.putMeal(estimated: true)
                store.cache.putDish(version: 1, energyKcal: 200)
                healthStore = .ok(authorizedNutrients: [])
            }

            @Test("書かず、控えも残さないこと。許可を得たあとに、キャッシュの料理をまとめて書くこと")
            func writesAfterAuthorizationGranted() async throws {
                try await HealthSyncEngine.fixture(healthStore: healthStore, store: store)
                    .exportNutrition()
                #expect(healthStore.nutritionWrites.isEmpty)
                #expect(store.healthDishWrites.isEmpty)

                let granted = HealthStoreMock.ok()
                try await HealthSyncEngine.fixture(healthStore: granted, store: store)
                    .exportNutrition()

                #expect(granted.nutritionWrites.count == 1)
            }
        }

        @Suite("推定できていない食事の料理があるとき")
        struct NotEstimatedYet {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                try store.cache.putMeal(estimated: false)
                store.cache.putDish(version: 1, energyKcal: 200)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書かず、推定できたとわかってから書くこと")
            func waitsForEstimated() async throws {
                try await engine.exportNutrition()
                #expect(healthStore.nutritionWrites.isEmpty)

                store.cache.write(.estimated, forMealId: Nutrition.mealId)
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.count == 1)
            }
        }

        @Suite("食事がまだ届いていない料理があるとき")
        struct MealNotArrivedYet {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock
            let engine: HealthSyncEngine

            init() throws {
                store = try .ok()
                store.cache.write(.estimated, forMealId: Nutrition.mealId)
                store.cache.putDish(version: 1, energyKcal: 200)
                healthStore = .ok()
                engine = .fixture(healthStore: healthStore, store: store)
            }

            @Test("書かず、食事が届いてから書くこと")
            func waitsForMeal() async throws {
                try await engine.exportNutrition()
                #expect(healthStore.nutritionWrites.isEmpty)

                try store.cache.putMeal(estimated: true)
                try await engine.exportNutrition()

                #expect(healthStore.nutritionWrites.count == 1)
            }
        }

        @Suite("書く値が1つも無い料理があるとき")
        struct DishWithoutValues {
            let store: SyncBoxMock<RecordCacheMock>
            let healthStore: HealthStoreMock

            init() throws {
                store = try .ok()
                try store.cache.putMeal(estimated: true)
                store.cache.upsert(Dish.fixture(id: Nutrition.dishId, mealId: Nutrition.mealId))
                store.cache.upsert(Ingredient.fixture(dishId: Nutrition.dishId, nutrients: [:]))
                healthStore = .ok()
            }

            @Test("書かず、控えも残さないこと")
            func writesNothing() async throws {
                try await HealthSyncEngine.fixture(healthStore: healthStore, store: store)
                    .exportNutrition()

                #expect(healthStore.nutritionWrites.isEmpty)
                #expect(store.healthDishWrites.isEmpty)
            }
        }

        @Suite("初めて食事を記録したあと")
        struct AfterFirstMeal {
            let store: SyncBoxMock<RecordCacheMock>

            init() throws {
                store = try .ok()
                try store.cache.putMeal(estimated: true)
                store.cache.putDish(version: 1, energyKcal: 200)
            }

            @Test("まだ求めていなければ、許可を求め、許可の画面が閉じたあとにキャッシュの料理を書くこと")
            func requestsThenWrites() async throws {
                let healthStore = HealthStoreMock.ok(nutritionRequestStatus: .notYetRequested)

                try await HealthSyncEngine.fixture(healthStore: healthStore, store: store)
                    .requestNutritionAuthorizationAfterMealRecorded()

                #expect(healthStore.nutritionAuthorizationRequests == 1)
                #expect(healthStore.nutritionWrites.count == 1)
            }

            @Test("求め済みなら、求めず、書きもしないこと")
            func doesNothingWhenAlreadyRequested() async throws {
                let healthStore = HealthStoreMock.ok(nutritionRequestStatus: .alreadyRequested)

                try await HealthSyncEngine.fixture(healthStore: healthStore, store: store)
                    .requestNutritionAuthorizationAfterMealRecorded()

                #expect(healthStore.nutritionAuthorizationRequests == 0)
                #expect(healthStore.nutritionWrites.isEmpty)
            }
        }

        @Suite("ヘルスケアに書けないとき")
        struct WriteFailure {
            let store: SyncBoxMock<RecordCacheMock>
            let reporting: ErrorReportingSessionMock

            init() throws {
                store = try .ok()
                reporting = .ok()
                try store.cache.putMeal(estimated: true)
                store.cache.putDish(version: 1, energyKcal: 200)
                store.cache.upsert(
                    Dish.fixture(
                        id: UUID(), mealId: Nutrition.mealId, name: "味噌汁", positionInMeal: 1))
            }

            @Test("栄養の書き込みの失敗として、1回だけ Sentry に送り、控えを残さないこと")
            func reportsOnce() async throws {
                let engine = HealthSyncEngine.fixture(
                    healthStore: .ok(nutritionFailure: SampleError()), store: store,
                    errorReporting: reporting)

                await #expect(throws: SampleError.self) {
                    try await engine.exportNutrition()
                }

                #expect(reporting.reported == [.healthNutritionWrite])
                #expect(store.healthDishWrites.isEmpty)
            }

            @Test("時間切れのときは、送らないこと")
            func doesNotReportTimeout() async throws {
                let engine = HealthSyncEngine.fixture(
                    healthStore: .ok(nutritionFailure: URLError(.timedOut)), store: store,
                    errorReporting: reporting)

                await #expect(throws: URLError.self) {
                    try await engine.exportNutrition()
                }

                #expect(reporting.reported.isEmpty)
            }
        }
    }
}

extension RecordCacheMock {
    fileprivate func putMeal(estimated: Bool) throws {
        upsert(
            try Meal.fixture(
                eatenAt: "2026-09-22T12:10:00+09:00", sentAt: "2026-09-22T12:11:00+09:00",
                id: HealthSyncEngineTests.Nutrition.mealId))
        if estimated {
            write(.estimated, forMealId: HealthSyncEngineTests.Nutrition.mealId)
        } else {
            write(.estimating, forMealId: HealthSyncEngineTests.Nutrition.mealId)
        }
    }

    /// 親子丼 1 つ。材料は 1 つで、量は 100 g（値はそのまま料理の合計になる）
    fileprivate func putDish(version: Int, energyKcal: Double, proteinG: Double? = nil) {
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
