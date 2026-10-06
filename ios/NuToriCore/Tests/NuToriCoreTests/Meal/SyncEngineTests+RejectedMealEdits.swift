import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    /// 推定できた食事（9月22日 12:10 に撮った）の親子丼 1 杯（ご飯 200 g・鶏もも肉 80 g）を直す書き込みを、サーバーが受け付けなかったとき
    @Suite("直す書き込みを受け付けなかった1行")
    struct RejectedMealEdits {
        typealias Writes = DishWrites

        static func engine(
            current: ClientTransportMock.Current, reason: String,
            store: SyncBoxMock<RecordCacheMock>
        ) -> SyncEngine {
            .fixture(
                store: store,
                transport: .sync(
                    rejectedWriteIndexes: [0], currents: [0: current],
                    rejectionReasons: [0: reason]))
        }

        /// 同期のあとのキャッシュの食事のカード。食事が消えていれば nil
        static func card(of store: SyncBoxMock<RecordCacheMock>) -> MealCard? {
            store.cache.meals[Writes.mealId].map { meal in
                MealCard(
                    meal: meal, status: .estimated, recordedOnThisDevice: true,
                    dishes: Array(store.cache.dishes.values),
                    ingredients: Array(store.cache.ingredients.values),
                    dishEstimationStatuses: store.cache.dishEstimationStatuses, unsentDishIds: [])
            }
        }

        static func line(_ result: SyncResult) throws -> RejectedMealLine {
            var lines = RejectedLines()
            lines.add(result.rejectedWrites)
            return try #require(lines.lines.compactMap(\.mealLine).first)
        }

        static func oyakodon(quantity: Double, version: Int) -> SyncedDish {
            SyncedDish(
                id: Writes.dishId, mealId: Writes.mealId, name: "親子丼",
                quantity: .init(value: quantity, unit: "杯", source: .estimated),
                positionInMeal: 0, version: version)
        }

        @Suite("時刻を直す書き込みを、範囲の外として受け付けなかったとき")
        struct EatenAtNotCorrected {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await Writes.seededStore()
                engine = RejectedMealEdits.engine(
                    current: .meal(try Writes.meal()), reason: "out_of_range", store: store)
                try await engine.correctMealTime(
                    mealId: Writes.mealId,
                    eatenAt: try Date("2026-09-22T19:40:00+09:00", strategy: .iso8601))
            }

            @Test("直そうとした時刻で「直せませんでした」を時刻の下に出し、サーバーの時刻に戻すこと")
            func showsLineBelowEatenAt() async throws {
                let line = try RejectedMealEdits.line(try await engine.sync())

                #expect(line.text == "19:40 に直せませんでした。")
                #expect(line.placement(in: RejectedMealEdits.card(of: store)) == .belowEatenAt)
                #expect(store.cache.meals[Writes.mealId]?.eatenAt == (try Writes.meal()).eatenAt)
            }
        }

        @Suite("時刻を直そうとした食事が消えていたとき")
        struct EatenAtOfDeletedMeal {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await Writes.seededStore()
                engine = RejectedMealEdits.engine(
                    current: .deletedMeal(mealId: Writes.mealId), reason: "record_not_found",
                    store: store)
                try await engine.correctMealTime(
                    mealId: Writes.mealId,
                    eatenAt: try Date("2026-09-22T19:40:00+09:00", strategy: .iso8601))
            }

            @Test("端末で見せていた時刻で「記録できませんでした」をカードを外した位置に出すこと")
            func showsLineOnTimeline() async throws {
                let line = try RejectedMealEdits.line(try await engine.sync())

                #expect(line.text == "19:40 の食事は、記録できませんでした。")
                #expect(line.placement(in: RejectedMealEdits.card(of: store)) == .timeline)
            }
        }

        @Suite("名前を直す書き込みを、範囲の外として受け付けなかったとき")
        struct NameNotCorrected {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await Writes.seededStore()
                engine = RejectedMealEdits.engine(
                    current: .dish(RejectedMealEdits.oyakodon(quantity: 1, version: 2)),
                    reason: "out_of_range", store: store)
                try await engine.renameDish(id: Writes.dishId, to: "カツ丼")
            }

            @Test("直そうとした名前で「直せませんでした」を料理の行の下に出すこと")
            func showsLineBelowDish() async throws {
                let line = try RejectedMealEdits.line(try await engine.sync())

                #expect(line.text == "カツ丼 に直せませんでした。")
                #expect(
                    line.placement(in: RejectedMealEdits.card(of: store))
                        == .belowDish(Writes.dishId))
                #expect(store.cache.dishes[Writes.dishId]?.name == "親子丼")
            }
        }

        @Suite("推定し直しで材料が入れ替わっていて、量を直せなかったとき")
        struct QuantityNotCorrectedForReplacedIngredients {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await Writes.seededStore()
                engine = RejectedMealEdits.engine(
                    current: .dish(RejectedMealEdits.oyakodon(quantity: 2, version: 3)),
                    reason: "ingredients_replaced", store: store)
                try await engine.correctDishQuantity(id: Writes.dishId, to: 1.5)
            }

            @Test("直そうとした量で「直せませんでした」を料理の行の下に出し、料理の今の値に戻すこと")
            func showsLineBelowDish() async throws {
                let line = try RejectedMealEdits.line(try await engine.sync())

                #expect(line.text == "1.5杯に直せませんでした。")
                #expect(
                    line.placement(in: RejectedMealEdits.card(of: store))
                        == .belowDish(Writes.dishId))
                #expect(store.cache.dishes[Writes.dishId]?.quantity?.value == 2)
            }
        }

        @Suite("直そうとした料理が消えていたとき")
        struct GoneDish {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await Writes.seededStore()
                engine = RejectedMealEdits.engine(
                    current: .deletedDish(dishId: Writes.dishId), reason: "record_not_found",
                    store: store)
                try await engine.renameDish(id: Writes.dishId, to: "カツ丼")
            }

            @Test("端末で見せていた名前で「記録できませんでした」を料理の行を外した位置に出すこと")
            func showsLineInDishList() async throws {
                let line = try RejectedMealEdits.line(try await engine.sync())

                #expect(line.text == "12:10 の食事の カツ丼 は、記録できませんでした。")
                #expect(
                    line.placement(in: RejectedMealEdits.card(of: store))
                        == .inDishList(positionInMeal: 0))
                #expect(line.placement(in: nil) == .timeline)
            }
        }

        @Suite("足した料理の食事が無かったとき")
        struct AddedDishWithoutMeal {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await Writes.seededStore()
                engine = RejectedMealEdits.engine(
                    current: .absent, reason: "record_not_found", store: store)
                try await engine.addDish(named: "味噌汁", toMeal: Writes.mealId)
            }

            @Test("「記録できませんでした」をその料理の並び順の位置に出すこと")
            func showsLineAtPosition() async throws {
                let line = try RejectedMealEdits.line(try await engine.sync())

                #expect(line.text == "12:10 の食事に足した味噌汁は、記録できませんでした。")
                #expect(
                    line.placement(in: RejectedMealEdits.card(of: store))
                        == .inDishList(positionInMeal: 1))
                #expect(line.placement(in: nil) == .timeline)
            }
        }

        @Suite("置き換わった前の材料の量を直せなかったとき")
        struct ReplacedIngredient {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await Writes.seededStore()
                engine = RejectedMealEdits.engine(
                    current: .deletedIngredient(ingredientId: Writes.riceId),
                    reason: "ingredients_replaced", store: store)
                try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)
            }

            @Test("「ご飯 150 g に直せませんでした」をその材料のあった位置に出すこと")
            func showsLineAtIngredientPosition() async throws {
                let line = try RejectedMealEdits.line(try await engine.sync())

                #expect(line.text == "ご飯 150 g に直せませんでした。")
                #expect(
                    line.placement(in: RejectedMealEdits.card(of: store))
                        == .inIngredientList(dishId: Writes.dishId, positionInDish: 0))
            }
        }

        @Suite("置き換わった前の材料の量を直せず、その材料のあった位置が無くなったとき")
        struct ReplacedIngredientWithoutIngredients {
            let store: SyncBoxMock<RecordCacheMock>
            let line: RejectedMealLine

            init() async throws {
                store = try await Writes.seededStore()
                let engine = RejectedMealEdits.engine(
                    current: .deletedIngredient(ingredientId: Writes.riceId),
                    reason: "ingredients_replaced", store: store)
                try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)
                line = try RejectedMealEdits.line(try await engine.sync())
                try await store.apply(
                    SyncBoxResult(kindChanges: [
                        KindChanges(
                            kind: .ingredient,
                            changes: [.ingredientDeletion(ingredientId: Writes.chickenId)])
                    ]))
            }

            @Test("料理の行の下に出すこと")
            func showsLineBelowDish() {
                #expect(
                    line.placement(in: RejectedMealEdits.card(of: store))
                        == .belowDish(Writes.dishId))
            }
        }

        @Suite("直そうとした材料が料理ごと消えていたとき")
        struct GoneIngredient {
            let store: SyncBoxMock<RecordCacheMock>
            let line: RejectedMealLine
            /// 料理の削除の印が届く前のカード
            let cardWithDish: MealCard?

            init() async throws {
                store = try await Writes.seededStore()
                let engine = RejectedMealEdits.engine(
                    current: .deletedIngredient(ingredientId: Writes.riceId),
                    reason: "record_not_found", store: store)
                try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)
                line = try RejectedMealEdits.line(try await engine.sync())
                cardWithDish = RejectedMealEdits.card(of: store)
                try await store.apply(
                    SyncBoxResult(kindChanges: [
                        KindChanges(kind: .dish, changes: [.dishDeletion(dishId: Writes.dishId)])
                    ]))
            }

            @Test("「記録できませんでした」を、残っている親の位置に出すこと")
            func showsLineAtRemainingParent() {
                #expect(line.text == "12:10 の食事の 親子丼 の ご飯 は、記録できませんでした。")
                #expect(
                    line.placement(in: cardWithDish)
                        == .inIngredientList(dishId: Writes.dishId, positionInDish: 0))
                #expect(
                    line.placement(in: RejectedMealEdits.card(of: store))
                        == .inDishList(positionInMeal: 0))
                #expect(line.placement(in: nil) == .timeline)
            }
        }

        @Suite("サーバーに値のある材料の量を、範囲の外として直せなかったとき")
        struct IngredientNotCorrected {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() async throws {
                store = try await Writes.seededStore()
                engine = RejectedMealEdits.engine(
                    current: .ingredient(
                        Writes.ingredient(
                            id: Writes.riceId, name: "ご飯", quantity: 200, position: 0)),
                    reason: "out_of_range", store: store)
                try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)
            }

            @Test("直そうとした量で「直せませんでした」を材料の行の下に出すこと")
            func showsLineBelowIngredient() async throws {
                let line = try RejectedMealEdits.line(try await engine.sync())

                #expect(line.text == "150 g に直せませんでした。")
                #expect(
                    line.placement(in: RejectedMealEdits.card(of: store))
                        == .belowIngredient(Writes.riceId))
                #expect(store.cache.ingredients[Writes.riceId]?.quantity == 200)
            }
        }

        @Suite("同じ食事のちがう記録を直す書き込みを、どちらも受け付けなかったとき")
        struct LinesOfSameMeal {
            let engine: SyncEngine

            init() async throws {
                let store = try await Writes.seededStore()
                engine = SyncEngine.fixture(
                    store: store,
                    transport: .sync(
                        rejectedWriteIndexes: [0, 1],
                        currents: [
                            0: .dish(RejectedMealEdits.oyakodon(quantity: 1, version: 2)),
                            1: .deletedIngredient(ingredientId: Writes.riceId),
                        ],
                        rejectionReasons: [0: "out_of_range", 1: "ingredients_replaced"]))
                try await engine.renameDish(id: Writes.dishId, to: "カツ丼")
                try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)
            }

            @Test("どちらの1行も残すこと")
            func keepsBothLines() async throws {
                var lines = RejectedLines()
                lines.add(try await engine.sync().rejectedWrites)

                #expect(
                    lines.lines.compactMap(\.mealLine).map(\.text) == [
                        "カツ丼 に直せませんでした。", "ご飯 150 g に直せませんでした。",
                    ])
            }
        }
    }
}
