import Foundation
import NuToriTestSupport
import Testing

@testable import NuToriAPI

extension NuToriAPIClientTests {
    @Suite("料理と材料の同期")
    struct DishSync {
        static let mealId = "00000000-0000-4000-8000-0000000000f1"
        static let dishId = "00000000-0000-4000-8000-0000000000d1"
        static let ingredientId = "00000000-0000-4000-8000-0000000000e1"

        @Suite("料理と材料の変更を取りに行ったとき")
        struct PullingDishChanges {
            let client: NuToriAPIClient

            init() {
                let dishId = DishSync.dishId
                let ingredientId = DishSync.ingredientId
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        json: """
                            {"changes":[
                              {"sequence":1,"kind":"dish","recordId":"\(dishId)",
                               "record":{"id":"\(dishId)","mealId":"\(DishSync.mealId)","name":"親子丼",
                                 "quantity":1,"unit":"杯","positionInMeal":0,"version":1}},
                              {"sequence":2,"kind":"ingredient","recordId":"\(ingredientId)",
                               "record":{"id":"\(ingredientId)","dishId":"\(dishId)","name":"鶏もも肉",
                                 "quantity":80,"unit":"g","edibleGramsPerUnit":1,"positionInDish":0,
                                 "nutrientSource":{"type":"food_composition","foodNumber":"11225"},
                                 "nutrients":{"energy_kcal":204,"protein_g":16.6,"future_nutrient_g":1.5}}},
                              {"sequence":3,"kind":"ingredient","recordId":"\(ingredientId)",
                               "record":{"id":"\(ingredientId)","dishId":"\(dishId)","name":"緑茶",
                                 "quantity":1,"unit":"本","edibleGramsPerUnit":500,"positionInDish":1,
                                 "nutrientSource":{"type":"nutrition_label","labelBasisGrams":250},
                                 "nutrients":{}}},
                              {"sequence":4,"kind":"ingredient","recordId":"\(ingredientId)",
                               "record":{"id":"\(ingredientId)","dishId":"\(dishId)","name":"ご飯",
                                 "quantity":1,"unit":"杯","edibleGramsPerUnit":150,"positionInDish":2,
                                 "nutrientSource":{"type":"estimated"},
                                 "nutrients":{"energy_kcal":156}}},
                              {"sequence":5,"kind":"ingredient","recordId":"\(ingredientId)",
                               "record":{"id":"\(ingredientId)","dishId":"\(dishId)","name":"ご飯",
                                 "quantity":1,"unit":"杯","edibleGramsPerUnit":150,"positionInDish":2,
                                 "nutrientSource":{"type":"measured"},"nutrients":{}}},
                              {"sequence":6,"kind":"dish_deletion","recordId":"\(dishId)","record":{}},
                              {"sequence":7,"kind":"ingredient_deletion","recordId":"\(ingredientId)","record":{}}
                            ],"hasMore":false,"nextAfterSequence":7,"startedOn":"2026-09-29"}
                            """
                    ),
                    sessionToken: { "session-1" }
                )
            }

            @Test("料理・材料・それぞれの削除の印を解き、知らない出どころは読み飛ばせる形で返すこと")
            func returnsDishChanges() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: .fixture())

                let dishId = try #require(UUID(uuidString: DishSync.dishId))
                let ingredientId = try #require(UUID(uuidString: DishSync.ingredientId))
                let mealId = try #require(UUID(uuidString: DishSync.mealId))
                func ingredient(
                    name: String, quantity: Double, unit: String, edibleGramsPerUnit: Double,
                    position: Int, source: SyncedIngredient.NutrientSource,
                    nutrients: [String: Double]
                ) -> SyncChange {
                    .ingredient(
                        SyncedIngredient(
                            id: ingredientId, dishId: dishId, name: name, quantity: quantity,
                            unit: unit, edibleGramsPerUnit: edibleGramsPerUnit,
                            positionInDish: position, nutrientSource: source, nutrients: nutrients))
                }
                #expect(
                    result
                        == .pulled(
                            SyncChangesPage(
                                changes: [
                                    .dish(
                                        SyncedDish(
                                            id: dishId, mealId: mealId, name: "親子丼", quantity: 1,
                                            unit: "杯", positionInMeal: 0, version: 1)),
                                    ingredient(
                                        name: "鶏もも肉", quantity: 80, unit: "g",
                                        edibleGramsPerUnit: 1, position: 0,
                                        source: .foodComposition(foodNumber: "11225"),
                                        nutrients: [
                                            "energy_kcal": 204, "protein_g": 16.6,
                                            "future_nutrient_g": 1.5,
                                        ]),
                                    ingredient(
                                        name: "緑茶", quantity: 1, unit: "本",
                                        edibleGramsPerUnit: 500, position: 1,
                                        source: .nutritionLabel(basisGrams: 250), nutrients: [:]),
                                    ingredient(
                                        name: "ご飯", quantity: 1, unit: "杯",
                                        edibleGramsPerUnit: 150, position: 2,
                                        source: .estimated, nutrients: ["energy_kcal": 156]),
                                    .unknown(kind: "ingredient"),
                                    .dishDeletion(dishId: dishId),
                                    .ingredientDeletion(ingredientId: ingredientId),
                                ],
                                hasMore: false,
                                nextAfterSequence: 7,
                                startedOn: "2026-09-29"
                            )))
            }
        }
    }
}
