import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("料理と材料の同期")
    struct DishKind {
        static let mealId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f1")!
        static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d1")!
        static let removedDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000d2")!
        static let ingredientId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e1")!
        static let removedIngredientId = UUID(
            uuidString: "00000000-0000-4000-8000-0000000000e2")!

        @Suite("親の食事と料理が届く前に、料理と材料を取りに行ったとき")
        struct PullingChildrenBeforeParents {
            let store: SyncBoxMock<RecordCacheMock>
            let engine: SyncEngine

            init() throws {
                store = try .ok()
                engine = .fixture(
                    store: store,
                    transport: .sync(pullPages: [
                        """
                        {"changes":[
                          \(DishKind.ingredientChange(sequence: 1, id: DishKind.ingredientId, dishId: DishKind.dishId)),
                          \(DishKind.ingredientChange(sequence: 2, id: DishKind.removedIngredientId, dishId: DishKind.removedDishId)),
                          \(DishKind.dishChange(sequence: 3, id: DishKind.dishId)),
                          \(DishKind.dishChange(sequence: 4, id: DishKind.removedDishId)),
                          {"sequence":5,"kind":"ingredient_deletion","recordId":"\(DishKind.removedIngredientId.uuidString)","record":{}},
                          {"sequence":6,"kind":"dish_deletion","recordId":"\(DishKind.removedDishId.uuidString)","record":{}}
                        ],"hasMore":false,"nextAfterSequence":6,"startedOn":null}
                        """
                    ]))
            }

            @Test("親が無くても、料理と材料をキャッシュに当てること")
            func appliesChildrenWithoutParents() async throws {
                _ = try await engine.sync()

                #expect(store.cache.meals.isEmpty)
                #expect(store.cache.dishes[DishKind.dishId]?.mealId == DishKind.mealId)
                #expect(store.cache.ingredients[DishKind.ingredientId]?.dishId == DishKind.dishId)
            }

            @Test("栄養の値は、知らない項目を読み飛ばして当てること")
            func appliesKnownNutrientsOnly() async throws {
                _ = try await engine.sync()

                #expect(
                    store.cache.ingredients[DishKind.ingredientId]?.nutrients == [
                        .energyKcal: 204
                    ])
            }

            @Test("削除の印の料理と材料をキャッシュから消すこと")
            func removesDeleted() async throws {
                _ = try await engine.sync()

                #expect(store.cache.dishes[DishKind.removedDishId] == nil)
                #expect(store.cache.ingredients[DishKind.removedIngredientId] == nil)
            }
        }

        static func dishChange(sequence: Int, id: UUID) -> String {
            """
            {"sequence":\(sequence),"kind":"dish","recordId":"\(id.uuidString)",
             "record":{"id":"\(id.uuidString)","mealId":"\(mealId.uuidString)","name":"親子丼",
               "quantity":1,"unit":"杯","quantitySource":"estimated","positionInMeal":0,"version":1}}
            """
        }

        static func ingredientChange(sequence: Int, id: UUID, dishId: UUID) -> String {
            """
            {"sequence":\(sequence),"kind":"ingredient","recordId":"\(id.uuidString)",
             "record":{"id":"\(id.uuidString)","dishId":"\(dishId.uuidString)","name":"鶏もも肉",
               "quantity":80,"quantitySource":"estimated","unit":"g","edibleGramsPerUnit":1,"positionInDish":0,
               "nutrientSource":{"type":"food_composition","foodNumber":"11225"},
               "nutrients":{"energy_kcal":204,"future_nutrient_g":1.5}}}
            """
        }
    }
}
