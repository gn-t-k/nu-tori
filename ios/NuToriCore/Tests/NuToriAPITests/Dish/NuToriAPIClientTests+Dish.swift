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

        @Suite("料理と材料の書き込みを送るとき")
        struct PushingDishWrites {
            let transport: ClientTransportMock
            let client: NuToriAPIClient
            let writes: [SyncWrite]

            init() throws {
                let dishId = try #require(UUID(uuidString: DishSync.dishId))
                let mealId = try #require(UUID(uuidString: DishSync.mealId))
                let ingredientId = try #require(UUID(uuidString: DishSync.ingredientId))
                writes = [
                    .createDish(
                        writeId: try #require(
                            UUID(uuidString: "00000000-0000-4000-8000-0000000000a1")),
                        dish: NewDish(id: dishId, mealId: mealId, name: "親子丼", positionInMeal: 0)),
                    .updateDish(
                        writeId: try #require(
                            UUID(uuidString: "00000000-0000-4000-8000-0000000000a2")),
                        correction: DishCorrection(
                            id: dishId, name: "カツ丼",
                            quantity: .init(
                                value: 2,
                                proportionedIngredients: [
                                    .init(ingredientId: ingredientId, quantity: 160)
                                ]))),
                    .updateIngredient(
                        writeId: try #require(
                            UUID(uuidString: "00000000-0000-4000-8000-0000000000a3")),
                        ingredientId: ingredientId, quantity: 150),
                    .deleteDish(
                        writeId: try #require(
                            UUID(uuidString: "00000000-0000-4000-8000-0000000000a4")),
                        dishId: dishId),
                ]
                transport = .ok(json: #"{"results":[]}"#)
                client = NuToriAPIClient(
                    serverURL: try #require(URL(string: "https://api.example")),
                    transport: transport,
                    appBuildGate: .sample,
                    sessionToken: { "session-1" }
                )
            }

            @Test("書き込み・料理・食事・材料の ID を、小文字の正規形で送ること")
            func sendsLowercasedIds() async throws {
                _ = try await client.pushSyncWrites(
                    writes, isFinalBatch: true, clientState: .fixture())

                let sent = try #require(transport.requests.first)
                #expect(
                    try PushSyncWritesPayload(sentBody: sent.body).writes == [
                        .createDish(
                            .init(
                                id: "00000000-0000-4000-8000-0000000000a1", _type: .createDish,
                                dishId: "00000000-0000-4000-8000-0000000000d1",
                                mealId: "00000000-0000-4000-8000-0000000000f1",
                                name: "親子丼", positionInMeal: 0)),
                        .updateDish(
                            .init(
                                id: "00000000-0000-4000-8000-0000000000a2", _type: .updateDish,
                                dishId: "00000000-0000-4000-8000-0000000000d1", name: "カツ丼",
                                quantity: .init(
                                    value: 2,
                                    proportionedIngredients: [
                                        .init(
                                            ingredientId: "00000000-0000-4000-8000-0000000000e1",
                                            quantity: 160)
                                    ]))),
                        .updateIngredient(
                            .init(
                                id: "00000000-0000-4000-8000-0000000000a3",
                                _type: .updateIngredient,
                                ingredientId: "00000000-0000-4000-8000-0000000000e1",
                                quantity: 150)),
                        .deleteDish(
                            .init(
                                id: "00000000-0000-4000-8000-0000000000a4", _type: .deleteDish,
                                dishId: "00000000-0000-4000-8000-0000000000d1")),
                    ])
            }
        }

        @Suite("推定し直しで置き換わった前の材料を直す書き込みを、受け付けなかったとき")
        struct PushingReplacedIngredientWrite {
            let client: NuToriAPIClient
            let writeId: UUID
            let ingredientId: UUID

            init() throws {
                writeId = try #require(UUID(uuidString: "00000000-0000-4000-8000-0000000000a1"))
                ingredientId = try #require(UUID(uuidString: DishSync.ingredientId))
                client = NuToriAPIClient(
                    serverURL: URL(string: "https://api.example")!,
                    transport: ClientTransportMock.ok(
                        json: """
                            {"results":[
                              {"writeId":"\(writeId.canonicalString)","result":"rejected","rejectionReason":"ingredients_replaced",
                               "current":{"status":"deleted","change":{"kind":"ingredient_deletion","recordId":"\(DishSync.ingredientId)","record":{}}}}
                            ]}
                            """
                    ),
                    appBuildGate: .sample,
                    sessionToken: { "session-1" }
                )
            }

            @Test("理由を材料が置き換わっていたと読み、今の値を材料の削除の印として読むこと")
            func readsIngredientsReplaced() async throws {
                let result = try await client.pushSyncWrites(
                    [
                        .updateIngredient(
                            writeId: writeId, ingredientId: ingredientId, quantity: 150)
                    ],
                    isFinalBatch: true, clientState: .fixture())

                #expect(
                    result
                        == .pushed([
                            SyncWriteResult(
                                writeId: writeId, outcome: .rejected(.ingredientsReplaced),
                                current: .deleted(.ingredientDeletion(ingredientId: ingredientId)))
                        ]))
            }
        }

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
                                 "quantity":1,"unit":"杯","quantitySource":"corrected","positionInMeal":0,"version":2}},
                              {"sequence":2,"kind":"ingredient","recordId":"\(ingredientId)",
                               "record":{"id":"\(ingredientId)","dishId":"\(dishId)","name":"鶏もも肉",
                                 "quantity":80,"quantitySource":"corrected","unit":"g","edibleGramsPerUnit":1,"positionInDish":0,
                                 "nutrientSource":{"type":"food_composition","foodNumber":"11225"},
                                 "nutrients":{"energy_kcal":204,"protein_g":16.6,"future_nutrient_g":1.5}}},
                              {"sequence":3,"kind":"ingredient","recordId":"\(ingredientId)",
                               "record":{"id":"\(ingredientId)","dishId":"\(dishId)","name":"緑茶",
                                 "quantity":1,"quantitySource":"estimated","unit":"本","edibleGramsPerUnit":500,"positionInDish":1,
                                 "nutrientSource":{"type":"nutrition_label","labelBasisGrams":250},
                                 "nutrients":{}}},
                              {"sequence":4,"kind":"ingredient","recordId":"\(ingredientId)",
                               "record":{"id":"\(ingredientId)","dishId":"\(dishId)","name":"ご飯",
                                 "quantity":1,"quantitySource":"estimated","unit":"杯","edibleGramsPerUnit":150,"positionInDish":2,
                                 "nutrientSource":{"type":"estimated"},
                                 "nutrients":{"energy_kcal":156}}},
                              {"sequence":5,"kind":"ingredient","recordId":"\(ingredientId)",
                               "record":{"id":"\(ingredientId)","dishId":"\(dishId)","name":"ご飯",
                                 "quantity":1,"quantitySource":"estimated","unit":"杯","edibleGramsPerUnit":150,"positionInDish":2,
                                 "nutrientSource":{"type":"measured"},"nutrients":{}}},
                              {"sequence":6,"kind":"dish_deletion","recordId":"\(dishId)","record":{}},
                              {"sequence":7,"kind":"ingredient_deletion","recordId":"\(ingredientId)","record":{}},
                              {"sequence":8,"kind":"dish","recordId":"\(dishId)",
                               "record":{"id":"\(dishId)","mealId":"\(DishSync.mealId)","name":"味噌汁",
                                 "positionInMeal":1,"version":1}},
                              {"sequence":9,"kind":"dish","recordId":"\(dishId)",
                               "record":{"id":"\(dishId)","mealId":"\(DishSync.mealId)","name":"味噌汁",
                                 "quantity":1,"positionInMeal":1,"version":1}}
                            ],"hasMore":false,"nextAfterSequence":9,"startedOn":"2026-09-29"}
                            """
                    ),
                    appBuildGate: .sample,
                    sessionToken: { "session-1" }
                )
            }

            @Test("料理・材料・それぞれの削除の印を解き、量の無い料理は量を持たず、知らない出どころと量のそろわない料理は読み飛ばせる形で返すこと")
            func returnsDishChanges() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 0, clientState: .fixture())

                let dishId = try #require(UUID(uuidString: DishSync.dishId))
                let ingredientId = try #require(UUID(uuidString: DishSync.ingredientId))
                let mealId = try #require(UUID(uuidString: DishSync.mealId))
                func ingredient(
                    name: String, quantity: Double, quantitySource: SyncedQuantitySource,
                    unit: String, edibleGramsPerUnit: Double,
                    position: Int, source: SyncedIngredient.NutrientSource,
                    nutrients: [String: Double]
                ) -> SyncChange {
                    .ingredient(
                        SyncedIngredient(
                            id: ingredientId, dishId: dishId, name: name, quantity: quantity,
                            quantitySource: quantitySource, unit: unit,
                            edibleGramsPerUnit: edibleGramsPerUnit,
                            positionInDish: position, nutrientSource: source, nutrients: nutrients))
                }
                #expect(
                    result
                        == .pulled(
                            SyncChangesPage(
                                changes: [
                                    .dish(
                                        SyncedDish(
                                            id: dishId, mealId: mealId, name: "親子丼",
                                            quantity: .init(
                                                value: 1, unit: "杯", source: .corrected),
                                            positionInMeal: 0, version: 2)),
                                    ingredient(
                                        name: "鶏もも肉", quantity: 80, quantitySource: .corrected,
                                        unit: "g",
                                        edibleGramsPerUnit: 1, position: 0,
                                        source: .foodComposition(foodNumber: "11225"),
                                        nutrients: [
                                            "energy_kcal": 204, "protein_g": 16.6,
                                            "future_nutrient_g": 1.5,
                                        ]),
                                    ingredient(
                                        name: "緑茶", quantity: 1, quantitySource: .estimated,
                                        unit: "本",
                                        edibleGramsPerUnit: 500, position: 1,
                                        source: .nutritionLabel(basisGrams: 250), nutrients: [:]),
                                    ingredient(
                                        name: "ご飯", quantity: 1, quantitySource: .estimated,
                                        unit: "杯",
                                        edibleGramsPerUnit: 150, position: 2,
                                        source: .estimated, nutrients: ["energy_kcal": 156]),
                                    .unknown(kind: "ingredient"),
                                    .dishDeletion(dishId: dishId),
                                    .ingredientDeletion(ingredientId: ingredientId),
                                    .dish(
                                        SyncedDish(
                                            id: dishId, mealId: mealId, name: "味噌汁", quantity: nil,
                                            positionInMeal: 1, version: 1)),
                                    .unknown(kind: "dish"),
                                ],
                                hasMore: false,
                                nextAfterSequence: 9,
                                startedOn: "2026-09-29"
                            )))
            }
        }
    }
}
