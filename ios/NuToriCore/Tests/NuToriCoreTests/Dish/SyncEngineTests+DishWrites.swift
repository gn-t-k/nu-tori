import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("料理と材料を直す")
    struct DishWrites {
        static let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!
        static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
        static let riceId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e1")!
        static let chickenId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e2")!

        /// 推定できた食事の、親子丼 1 杯（ご飯 200 g・鶏もも肉 80 g。料理ごとの推定の状態は推定できた）
        static func seededStore() async throws -> SyncBoxMock<RecordCacheMock> {
            let store = try SyncBoxMock<RecordCacheMock>.ok()
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .dish,
                        changes: [
                            .dish(
                                SyncedDish(
                                    id: dishId, mealId: mealId, name: "親子丼",
                                    quantity: .init(value: 1, unit: "杯", source: .estimated),
                                    positionInMeal: 0, version: 1))
                        ]),
                    KindChanges(
                        kind: .dishEstimationStatus,
                        changes: [.dishEstimationStatus(.init(dishId: dishId, status: .estimated))]),
                    KindChanges(
                        kind: .ingredient,
                        changes: [
                            .ingredient(
                                ingredient(id: riceId, name: "ご飯", quantity: 200, position: 0)),
                            .ingredient(
                                ingredient(id: chickenId, name: "鶏もも肉", quantity: 80, position: 1)),
                        ]),
                    KindChanges(kind: .meal, changes: [.meal(try meal())]),
                ]))
            return store
        }

        static func meal() throws -> SyncedMeal {
            SyncedMeal(
                id: mealId,
                eatenAt: Date(timeIntervalSince1970: 1_790_046_600),
                eatenUtcOffsetSeconds: 32_400,
                sentAt: Date(timeIntervalSince1970: 1_790_046_660),
                sentTimeZone: try #require(TimeZone(identifier: "Asia/Tokyo")),
                entryMethod: .captured,
                photoIds: [UUID()])
        }

        static func ingredient(id: UUID, name: String, quantity: Double, position: Int)
            -> SyncedIngredient
        {
            SyncedIngredient(
                id: id, dishId: dishId, name: name, quantity: quantity, quantitySource: .estimated,
                unit: "g", edibleGramsPerUnit: 1, positionInDish: position,
                nutrientSource: .estimated, nutrients: ["energy_kcal": 150])
        }

        @Suite("料理を足したとき")
        struct Adding {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
            }

            @Test("前後の空白を除いた名前で、量の無い料理を、その食事の料理の最後の次の並び順に置くこと")
            func addsDishAfterLast() async throws {
                let dish = try #require(
                    try await engine.addDish(named: " 味噌汁\n", toMeal: DishWrites.mealId))

                #expect(dish.name == "味噌汁")
                #expect(dish.mealId == DishWrites.mealId)
                #expect(dish.quantity == nil)
                #expect(dish.positionInMeal == 1)
                #expect(store.cache.dishes[dish.id] == dish)
            }

            @Test("料理の ID を UUID の版 4 で振ること")
            func usesVersion4Id() async throws {
                let dish = try #require(
                    try await engine.addDish(named: "味噌汁", toMeal: DishWrites.mealId))

                #expect(dish.id.uuidString.dropFirst(14).first == "4")
            }

            @Test("送り待ちに料理の種類の名前で入れてから、キャッシュに料理を置くこと")
            func enqueuesThenCaches() async throws {
                _ = try await engine.addDish(named: "味噌汁", toMeal: DishWrites.mealId)

                #expect(store.entries.map(\.kind) == [.dish])
                #expect(
                    store.saves.suffix(2) == [
                        .pending(added: 1, removed: 0), .cache(changes: 1, afterSequence: nil),
                    ])
            }

            @Test("送ると、料理の ID・食事の ID・名前・並び順を、料理を作る書き込みで送ること")
            func sendsCreateDish() async throws {
                let dish = try #require(
                    try await engine.addDish(named: "味噌汁", toMeal: DishWrites.mealId))

                _ = try await engine.sync()

                let write = try #require(try transport.pushBodies.first?.writes.first)
                #expect(
                    write
                        == .createDish(
                            writeId: write.writeId,
                            dish: NewDish(
                                id: dish.id, mealId: DishWrites.mealId, name: "味噌汁",
                                positionInMeal: 1)))
            }

            @Test("名前が前後の空白を除いて空なら、足さずに nil を返すこと")
            func ignoresBlankName() async throws {
                let dish = try await engine.addDish(named: "  ", toMeal: DishWrites.mealId)

                #expect(dish == nil)
                #expect(store.entries.isEmpty)
                #expect(store.cache.dishes.count == 1)
            }
        }

        @Suite("料理が1つも無い食事に、料理を足したとき")
        struct AddingToMealWithoutDishes {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try .ok()
                try await store.apply(
                    SyncBoxResult(kindChanges: [
                        KindChanges(kind: .meal, changes: [.meal(try DishWrites.meal())])
                    ]))
                engine = .fixture(store: store, transport: .sync())
            }

            @Test("並び順を 0 にすること")
            func placesFirst() async throws {
                let dish = try await engine.addDish(named: "味噌汁", toMeal: DishWrites.mealId)

                #expect(dish?.positionInMeal == 0)
            }
        }

        @Suite("サーバーが料理を作る書き込みを受け付けず、サーバーに料理が無いとき")
        struct AddingRejectedWithoutValue {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                engine = .fixture(
                    store: store,
                    transport: .sync(
                        rejectedWriteIndexes: [0], currents: [0: .absent],
                        rejectionReasons: [0: "record_not_found"]))
            }

            @Test("足した料理をキャッシュから外すこと")
            func removesAddedDish() async throws {
                let dish = try #require(
                    try await engine.addDish(named: "味噌汁", toMeal: DishWrites.mealId))

                _ = try await engine.sync()

                #expect(store.cache.dishes[dish.id] == nil)
                #expect(store.cache.dishes[DishWrites.dishId] != nil)
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("料理の量を直したとき")
        struct CorrectingQuantity {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
            }

            @Test("送り待ちに入れてから、料理の量と比例させた材料の量をキャッシュに当てること")
            func appliesProportionToCache() async throws {
                try await engine.correctDishQuantity(id: DishWrites.dishId, to: 1.5)

                #expect(store.entries.map(\.kind) == [.dish])
                #expect(
                    store.saves.suffix(3) == [
                        .pending(added: 1, removed: 0), .cache(changes: 1, afterSequence: nil),
                        .cache(changes: 2, afterSequence: nil),
                    ])
                #expect(
                    store.cache.dishes[DishWrites.dishId]?.quantity
                        == Dish.Quantity(value: 1.5, unit: "杯", source: .corrected))
                #expect(store.cache.ingredients[DishWrites.riceId]?.quantity == 300)
                #expect(store.cache.ingredients[DishWrites.chickenId]?.quantity == 120)
                #expect(store.cache.ingredients[DishWrites.riceId]?.quantitySource == .estimated)
            }

            @Test("送ると、名前と直した量と比例させた材料の量を、料理を直す書き込み1つで送ること")
            func sendsOneUpdateDish() async throws {
                try await engine.correctDishQuantity(id: DishWrites.dishId, to: 1.5)

                _ = try await engine.sync()

                let writes = try #require(transport.pushBodies.first).writes
                try #require(writes.count == 1)
                #expect(
                    writes
                        == [
                            .updateDish(
                                writeId: writes[0].writeId,
                                correction: DishCorrection(
                                    id: DishWrites.dishId, name: "親子丼",
                                    quantity: .init(
                                        value: 1.5,
                                        proportionedIngredients: [
                                            .init(ingredientId: DishWrites.riceId, quantity: 300),
                                            .init(
                                                ingredientId: DishWrites.chickenId, quantity: 120),
                                        ])))
                        ])
            }

            @Test("受け付ける範囲の外の量なら、送らずにキャッシュの料理をそのまま返すこと")
            func ignoresOutOfRange() async throws {
                let dish = try await engine.correctDishQuantity(id: DishWrites.dishId, to: 0)

                #expect(dish.quantity?.value == 1)
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("料理の名前を直したとき")
        struct Renaming {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
            }

            @Test("送り待ちに入れてから、キャッシュの料理の名前を直すこと")
            func renamesInCache() async throws {
                let dish = try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")

                #expect(dish.name == "カツ丼")
                #expect(store.cache.dishes[DishWrites.dishId]?.name == "カツ丼")
                #expect(store.entries.map(\.kind) == [.dish])
            }

            @Test("送ると、直した名前と今の量と今の材料の量を、料理を直す書き込みで送ること")
            func sendsUpdateDish() async throws {
                _ = try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")

                _ = try await engine.sync()

                let write = try #require(try transport.pushBodies.first?.writes.first)
                #expect(
                    write
                        == .updateDish(
                            writeId: write.writeId,
                            correction: DishCorrection(
                                id: DishWrites.dishId, name: "カツ丼",
                                quantity: .init(
                                    value: 1,
                                    proportionedIngredients: [
                                        .init(ingredientId: DishWrites.riceId, quantity: 200),
                                        .init(ingredientId: DishWrites.chickenId, quantity: 80),
                                    ]))))
            }

            @Test("名前を空にしたら、送らずに前の名前の料理を返すこと")
            func keepsPreviousNameForBlank() async throws {
                let dish = try await engine.renameDish(id: DishWrites.dishId, to: " ")

                #expect(dish.name == "親子丼")
                #expect(store.entries.isEmpty)
            }

            @Test("キャッシュに無い料理は、直さずに投げること")
            func throwsForUnknownDish() async throws {
                let unknownId = UUID()

                await #expect(throws: SyncEngine.UnknownRecordError(recordId: unknownId)) {
                    _ = try await engine.renameDish(id: unknownId, to: "カツ丼")
                }
            }
        }

        @Suite("材料の量を直したとき")
        struct CorrectingIngredient {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                transport = .sync()
                engine = .fixture(store: store, transport: transport)
            }

            @Test("送り待ちに入れてから、材料の量と出どころを「直した」にしてキャッシュに当て、料理の量は変えないこと")
            func correctsInCache() async throws {
                let ingredient = try await engine.correctIngredientQuantity(
                    id: DishWrites.riceId, to: 150)

                #expect(ingredient.quantity == 150)
                #expect(store.entries.map(\.kind) == [.ingredient])
                #expect(store.cache.ingredients[DishWrites.riceId]?.quantity == 150)
                #expect(store.cache.ingredients[DishWrites.riceId]?.quantitySource == .corrected)
                #expect(store.cache.dishes[DishWrites.dishId]?.quantity?.value == 1)
            }

            @Test("送ると、材料の ID と直した量を、材料を直す書き込みで送ること")
            func sendsUpdateIngredient() async throws {
                _ = try await engine.correctIngredientQuantity(id: DishWrites.riceId, to: 150)

                _ = try await engine.sync()

                let write = try #require(try transport.pushBodies.first?.writes.first)
                #expect(
                    write
                        == .updateIngredient(
                            writeId: write.writeId, ingredientId: DishWrites.riceId, quantity: 150))
            }

            @Test("受け付ける範囲の外の量なら、送らずにキャッシュの材料をそのまま返すこと")
            func ignoresOutOfRange() async throws {
                let ingredient = try await engine.correctIngredientQuantity(
                    id: DishWrites.riceId, to: -10)

                #expect(ingredient.quantity == 200)
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("料理を消したとき")
        struct Deleting {
            let store: SyncBoxMock<RecordCacheMock>
            let transport: ClientTransportMock
            let nutritionHealthExport: NutritionHealthExportMock
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                transport = .sync()
                nutritionHealthExport = .ok()
                engine = .fixture(
                    store: store, transport: transport,
                    nutritionHealthExport: nutritionHealthExport)
            }

            @Test("その場で、料理と材料と料理ごとの推定の状態をキャッシュから消し、食事は残すこと")
            func removesFromCache() async throws {
                try await engine.deleteDish(id: DishWrites.dishId)

                #expect(store.cache.dishes.isEmpty)
                #expect(store.cache.ingredients.isEmpty)
                #expect(store.cache.dishEstimationStatuses.isEmpty)
                #expect(store.cache.meals[DishWrites.mealId] != nil)
                #expect(store.entries.map(\.kind) == [.dish])
            }

            @Test("ヘルスケアから料理を消しに行くこと")
            func exportsNutrition() async throws {
                try await engine.deleteDish(id: DishWrites.dishId)

                #expect(nutritionHealthExport.exportCount == 1)
            }

            @Test("送ると、料理の ID を、料理を消す書き込みで送ること")
            func sendsDeleteDish() async throws {
                try await engine.deleteDish(id: DishWrites.dishId)

                _ = try await engine.sync()

                let write = try #require(try transport.pushBodies.first?.writes.first)
                #expect(write == .deleteDish(writeId: write.writeId, dishId: DishWrites.dishId))
            }
        }

        @Suite("推定し直しで材料が入れ替わっていて、料理の量を直す書き込みを受け付けなかったとき")
        struct QuantityRejectedForReplacedIngredients {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                engine = .fixture(
                    store: store,
                    transport: .sync(
                        rejectedWriteIndexes: [0],
                        currents: [
                            0: .dish(
                                SyncedDish(
                                    id: DishWrites.dishId, mealId: DishWrites.mealId,
                                    name: "親子丼",
                                    quantity: .init(value: 2, unit: "杯", source: .estimated),
                                    positionInMeal: 0, version: 3))
                        ],
                        rejectionReasons: [0: "ingredients_replaced"]))
                try await engine.correctDishQuantity(id: DishWrites.dishId, to: 1.5)
            }

            @Test("料理の量を、サーバーの料理の今の値に戻すこと")
            func restoresServerQuantity() async throws {
                _ = try await engine.sync()

                #expect(
                    store.cache.dishes[DishWrites.dishId]?.quantity
                        == Dish.Quantity(value: 2, unit: "杯", source: .estimated))
                #expect(store.entries.isEmpty)
            }
        }

        @Suite("推定し直しで置き換わった前の材料の量を直す書き込みを、受け付けなかったとき")
        struct IngredientRejectedAsReplaced {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                engine = .fixture(
                    store: store,
                    transport: .sync(
                        rejectedWriteIndexes: [0],
                        currents: [0: .deletedIngredient(ingredientId: DishWrites.riceId)],
                        rejectionReasons: [0: "ingredients_replaced"]))
                _ = try await engine.correctIngredientQuantity(id: DishWrites.riceId, to: 150)
            }

            @Test("置き換わった前の材料を、削除の印でキャッシュから外すこと")
            func removesReplacedIngredient() async throws {
                _ = try await engine.sync()

                #expect(store.cache.ingredients[DishWrites.riceId] == nil)
                #expect(store.cache.ingredients[DishWrites.chickenId] != nil)
            }
        }

        @Suite("サーバーに料理が無く、料理を直す書き込みを受け付けなかったとき")
        struct UpdateRejectedWithoutValue {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                engine = .fixture(
                    store: store,
                    transport: .sync(
                        rejectedWriteIndexes: [0], currents: [0: .absent],
                        rejectionReasons: [0: "record_not_found"]))
                _ = try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")
            }

            @Test("料理をキャッシュから外すこと")
            func removesDish() async throws {
                _ = try await engine.sync()

                #expect(store.cache.dishes[DishWrites.dishId] == nil)
            }
        }

        @Suite("サーバーに材料が無く、材料を直す書き込みを受け付けなかったとき")
        struct IngredientRejectedWithoutValue {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await DishWrites.seededStore()
                engine = .fixture(
                    store: store,
                    transport: .sync(
                        rejectedWriteIndexes: [0], currents: [0: .absent],
                        rejectionReasons: [0: "record_not_found"]))
                _ = try await engine.correctIngredientQuantity(id: DishWrites.riceId, to: 150)
            }

            @Test("材料をキャッシュから外すこと")
            func removesIngredient() async throws {
                _ = try await engine.sync()

                #expect(store.cache.ingredients[DishWrites.riceId] == nil)
            }
        }
    }
}
