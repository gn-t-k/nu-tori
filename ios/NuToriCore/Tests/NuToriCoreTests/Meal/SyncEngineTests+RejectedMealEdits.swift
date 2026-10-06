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

        @Test("時刻を直す書き込みは、直そうとした時刻で「直せませんでした」を時刻の下に出し、サーバーの時刻に戻すこと")
        func eatenAtNotCorrected() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(
                current: .meal(try Writes.meal()), reason: "out_of_range", store: store)
            try await engine.correctMealTime(
                mealId: Writes.mealId,
                eatenAt: try Date("2026-09-22T19:40:00+09:00", strategy: .iso8601))

            let line = try Self.line(try await engine.sync())

            #expect(line.text == "19:40 に直せませんでした。")
            #expect(line.placement(in: Self.card(of: store)) == .belowEatenAt)
            #expect(store.cache.meals[Writes.mealId]?.eatenAt == (try Writes.meal()).eatenAt)
        }

        @Test("時刻を直そうとした食事が消えていたら、端末で見せていた時刻で「記録できませんでした」をカードを外した位置に出すこと")
        func eatenAtOfDeletedMeal() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(
                current: .deletedMeal(mealId: Writes.mealId), reason: "record_not_found",
                store: store)
            try await engine.correctMealTime(
                mealId: Writes.mealId,
                eatenAt: try Date("2026-09-22T19:40:00+09:00", strategy: .iso8601))

            let line = try Self.line(try await engine.sync())

            #expect(line.text == "19:40 の食事は、記録できませんでした。")
            #expect(line.placement(in: Self.card(of: store)) == .timeline)
        }

        @Test("名前を直す書き込みは、直そうとした名前で「直せませんでした」を料理の行の下に出すこと")
        func nameNotCorrected() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(
                current: .dish(Self.oyakodon(quantity: 1, version: 2)), reason: "out_of_range",
                store: store)
            try await engine.renameDish(id: Writes.dishId, to: "カツ丼")

            let line = try Self.line(try await engine.sync())

            #expect(line.text == "カツ丼 に直せませんでした。")
            #expect(line.placement(in: Self.card(of: store)) == .belowDish(Writes.dishId))
            #expect(store.cache.dishes[Writes.dishId]?.name == "親子丼")
        }

        @Test("推定し直しで材料が入れ替わっていて量を直せなかったら、直そうとした量で「直せませんでした」を料理の行の下に出し、料理の今の値に戻すこと")
        func quantityNotCorrectedForReplacedIngredients() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(
                current: .dish(Self.oyakodon(quantity: 2, version: 3)),
                reason: "ingredients_replaced", store: store)
            try await engine.correctDishQuantity(id: Writes.dishId, to: 1.5)

            let line = try Self.line(try await engine.sync())

            #expect(line.text == "1.5杯に直せませんでした。")
            #expect(line.placement(in: Self.card(of: store)) == .belowDish(Writes.dishId))
            #expect(store.cache.dishes[Writes.dishId]?.quantity?.value == 2)
        }

        @Test("直そうとした料理が消えていたら、端末で見せていた名前で「記録できませんでした」を料理の行を外した位置に出すこと")
        func goneDish() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(
                current: .deletedDish(dishId: Writes.dishId), reason: "record_not_found",
                store: store)
            try await engine.renameDish(id: Writes.dishId, to: "カツ丼")

            let line = try Self.line(try await engine.sync())

            #expect(line.text == "12:10 の食事の カツ丼 は、記録できませんでした。")
            #expect(line.placement(in: Self.card(of: store)) == .inDishList(positionInMeal: 0))
            #expect(line.placement(in: nil) == .timeline)
        }

        @Test("足した料理の食事が無かったら、「記録できませんでした」をその料理の並び順の位置に出すこと")
        func addedDishWithoutMeal() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(current: .absent, reason: "record_not_found", store: store)
            try await engine.addDish(named: "味噌汁", toMeal: Writes.mealId)

            let line = try Self.line(try await engine.sync())

            #expect(line.text == "12:10 の食事に足した味噌汁は、記録できませんでした。")
            #expect(line.placement(in: Self.card(of: store)) == .inDishList(positionInMeal: 1))
            #expect(line.placement(in: nil) == .timeline)
        }

        @Test("置き換わった前の材料の量を直せなかったら、「ご飯 150 g に直せませんでした」をその材料のあった位置に出すこと")
        func replacedIngredient() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(
                current: .deletedIngredient(ingredientId: Writes.riceId),
                reason: "ingredients_replaced", store: store)
            try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)

            let line = try Self.line(try await engine.sync())

            #expect(line.text == "ご飯 150 g に直せませんでした。")
            #expect(
                line.placement(in: Self.card(of: store))
                    == .inIngredientList(dishId: Writes.dishId, positionInDish: 0))
        }

        @Test("置き換わった前の材料のあった位置が無ければ、料理の行の下に出すこと")
        func replacedIngredientWithoutIngredients() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(
                current: .deletedIngredient(ingredientId: Writes.riceId),
                reason: "ingredients_replaced", store: store)
            try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)
            let line = try Self.line(try await engine.sync())
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(
                        kind: .ingredient,
                        changes: [.ingredientDeletion(ingredientId: Writes.chickenId)])
                ]))

            #expect(line.placement(in: Self.card(of: store)) == .belowDish(Writes.dishId))
        }

        @Test("直そうとした材料が料理ごと消えていたら、「記録できませんでした」を、残っている親の位置に出すこと")
        func goneIngredient() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(
                current: .deletedIngredient(ingredientId: Writes.riceId),
                reason: "record_not_found", store: store)
            try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)

            let line = try Self.line(try await engine.sync())
            let withDish = Self.card(of: store)
            try await store.apply(
                SyncBoxResult(kindChanges: [
                    KindChanges(kind: .dish, changes: [.dishDeletion(dishId: Writes.dishId)])
                ]))

            #expect(line.text == "12:10 の食事の 親子丼 の ご飯 は、記録できませんでした。")
            #expect(
                line.placement(in: withDish)
                    == .inIngredientList(dishId: Writes.dishId, positionInDish: 0))
            #expect(line.placement(in: Self.card(of: store)) == .inDishList(positionInMeal: 0))
            #expect(line.placement(in: nil) == .timeline)
        }

        @Test("サーバーに値のある材料の量を直せなかったら、直そうとした量で「直せませんでした」を材料の行の下に出すこと")
        func ingredientNotCorrected() async throws {
            let store = try await Writes.seededStore()
            let engine = Self.engine(
                current: .ingredient(
                    Writes.ingredient(id: Writes.riceId, name: "ご飯", quantity: 200, position: 0)),
                reason: "out_of_range", store: store)
            try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)

            let line = try Self.line(try await engine.sync())

            #expect(line.text == "150 g に直せませんでした。")
            #expect(line.placement(in: Self.card(of: store)) == .belowIngredient(Writes.riceId))
            #expect(store.cache.ingredients[Writes.riceId]?.quantity == 200)
        }

        @Test("同じ食事のちがう記録の1行は、どちらも残すこと")
        func linesOfSameMeal() async throws {
            let store = try await Writes.seededStore()
            let engine = SyncEngine.fixture(
                store: store,
                transport: .sync(
                    rejectedWriteIndexes: [0, 1],
                    currents: [
                        0: .dish(Self.oyakodon(quantity: 1, version: 2)),
                        1: .deletedIngredient(ingredientId: Writes.riceId),
                    ],
                    rejectionReasons: [0: "out_of_range", 1: "ingredients_replaced"]))
            try await engine.renameDish(id: Writes.dishId, to: "カツ丼")
            try await engine.correctIngredientQuantity(id: Writes.riceId, to: 150)

            var lines = RejectedLines()
            lines.add(try await engine.sync().rejectedWrites)

            #expect(
                lines.lines.compactMap(\.mealLine).map(\.text) == [
                    "カツ丼 に直せませんでした。", "ご飯 150 g に直せませんでした。",
                ])
        }

        static func oyakodon(quantity: Double, version: Int) -> SyncedDish {
            SyncedDish(
                id: Writes.dishId, mealId: Writes.mealId, name: "親子丼",
                quantity: .init(value: quantity, unit: "杯", source: .estimated),
                positionInMeal: 0, version: version)
        }
    }
}
