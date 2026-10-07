import Foundation
import Testing

@testable import NuToriAPI

extension FakeSyncServerTests {
    static let dishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e2")!
    static let addedDishId = UUID(uuidString: "00000000-0000-4000-8000-0000000000e3")!
    static let riceId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f2")!
    static let porkId = UUID(uuidString: "00000000-0000-4000-8000-0000000000f3")!

    static func ingredient(
        _ id: UUID, dishId: UUID, name: String, quantity: Double,
        source: SyncedQuantitySource = .estimated, position: Int = 0
    ) -> SyncedIngredient {
        SyncedIngredient(
            id: id, dishId: dishId, name: name, quantity: quantity, quantitySource: source,
            unit: "g", edibleGramsPerUnit: 1, positionInDish: position, nutrientSource: .estimated,
            nutrients: ["energy_kcal": 1.5])
    }

    /// 推定し直しで、名前から量と材料を作る。「謎の料理」は材料を推定できない
    static let estimate: @Sendable (UUID, String) -> FakeSyncServer.DishEstimate? = {
        dishId, name in
        guard name != "謎の料理" else { return nil }
        return FakeSyncServer.DishEstimate(
            quantity: .init(value: 1, unit: "皿", source: .estimated),
            ingredients: [
                FakeSyncServerTests.ingredient(
                    FakeSyncServerTests.porkId, dishId: dishId, name: "豚ロース", quantity: 100)
            ])
    }

    static func page(_ changes: [SyncChange], next: Int) -> NuToriAPIClient.PullSyncChangesResult {
        .pulled(
            SyncChangesPage(
                changes: changes, hasMore: false, nextAfterSequence: next,
                startedOn: FakeSyncServerTests.startedOn))
    }

    @Suite("料理を足す書き込みを受け付けたとき")
    struct DishAdded {
        let meal: SyncedMeal
        let client: NuToriAPIClient

        init() async throws {
            let meal = try SyncedMeal.fixture()
            self.meal = meal
            client = FakeSyncServerTests.client(
                .init(
                    records: [.meal(meal)], startedOn: FakeSyncServerTests.startedOn,
                    estimateDish: FakeSyncServerTests.estimate))
            _ = try await client.pushSyncWrites(
                [
                    .createDish(
                        writeId: UUID(),
                        dish: NewDish(
                            id: FakeSyncServerTests.addedDishId, mealId: meal.id, name: "カツ丼",
                            positionInMeal: 1))
                ], isFinalBatch: true, clientState: .fixture())
        }

        @Test("最初の取得で量の無い料理と推定中を、次の取得で推定した量と材料と推定できたことを返すこと")
        func estimatesOnNextPull() async throws {
            let first = try await client.pullSyncChanges(afterSequence: 1, clientState: .fixture())
            let second = try await client.pullSyncChanges(afterSequence: 3, clientState: .fixture())

            let added = SyncedDish(
                id: FakeSyncServerTests.addedDishId, mealId: meal.id, name: "カツ丼", quantity: nil,
                positionInMeal: 1, version: 1)
            #expect(
                first
                    == FakeSyncServerTests.page(
                        [
                            .dish(added),
                            .dishEstimationStatus(
                                .init(dishId: FakeSyncServerTests.addedDishId, status: .estimating)),
                        ], next: 3))
            #expect(
                second
                    == FakeSyncServerTests.page(
                        [
                            .dish(
                                SyncedDish(
                                    id: FakeSyncServerTests.addedDishId, mealId: meal.id,
                                    name: "カツ丼",
                                    quantity: .init(value: 1, unit: "皿", source: .estimated),
                                    positionInMeal: 1, version: 2)),
                            .ingredient(
                                FakeSyncServerTests.ingredient(
                                    FakeSyncServerTests.porkId,
                                    dishId: FakeSyncServerTests.addedDishId, name: "豚ロース",
                                    quantity: 100)),
                            .dishEstimationStatus(
                                .init(dishId: FakeSyncServerTests.addedDishId, status: .estimated)),
                        ], next: 6))
        }
    }

    @Suite("推定した料理があるとき")
    struct EstimatedDish {
        let dish: SyncedDish
        let rice: SyncedIngredient
        let client: NuToriAPIClient

        init() throws {
            let dish = try SyncedDish.fixture(mealId: try SyncedMeal.fixture().id)
            let rice = FakeSyncServerTests.ingredient(
                FakeSyncServerTests.riceId, dishId: dish.id, name: "ご飯", quantity: 200)
            self.dish = dish
            self.rice = rice
            client = FakeSyncServerTests.client(
                .init(
                    records: [.dish(dish), .ingredient(rice)],
                    startedOn: FakeSyncServerTests.startedOn,
                    estimateDish: FakeSyncServerTests.estimate))
        }

        @Suite("名前を直したとき")
        struct Renamed {
            let dish: SyncedDish
            let client: NuToriAPIClient
            let rice: SyncedIngredient

            init() async throws {
                let base = try EstimatedDish()
                dish = base.dish
                rice = base.rice
                client = base.client
                _ = try await client.pushSyncWrites(
                    [
                        .updateDish(
                            writeId: UUID(),
                            correction: DishCorrection(
                                id: dish.id, name: "カツ丼",
                                quantity: .init(
                                    value: 1,
                                    proportionedIngredients: [
                                        .init(ingredientId: rice.id, quantity: 200)
                                    ])))
                    ], isFinalBatch: true, clientState: .fixture())
            }

            @Test("推定中を返し、次の取得で前の材料を消して推定し直した量と材料を返すこと")
            func reestimatesRenamedDish() async throws {
                let first = try await client.pullSyncChanges(
                    afterSequence: 2, clientState: .fixture())
                let second = try await client.pullSyncChanges(
                    afterSequence: 4, clientState: .fixture())

                #expect(
                    first
                        == FakeSyncServerTests.page(
                            [
                                .dish(
                                    SyncedDish(
                                        id: dish.id, mealId: dish.mealId, name: "カツ丼",
                                        quantity: dish.quantity, positionInMeal: 0, version: 2)),
                                .dishEstimationStatus(.init(dishId: dish.id, status: .estimating)),
                            ], next: 4))
                #expect(
                    second
                        == FakeSyncServerTests.page(
                            [
                                .ingredientDeletion(ingredientId: rice.id),
                                .dish(
                                    SyncedDish(
                                        id: dish.id, mealId: dish.mealId, name: "カツ丼",
                                        quantity: .init(value: 1, unit: "皿", source: .estimated),
                                        positionInMeal: 0, version: 3)),
                                .ingredient(
                                    FakeSyncServerTests.ingredient(
                                        FakeSyncServerTests.porkId, dishId: dish.id,
                                        name: "豚ロース", quantity: 100)),
                                .dishEstimationStatus(.init(dishId: dish.id, status: .estimated)),
                            ], next: 8))
            }
        }

        @Suite("材料を推定できない名前に直したとき")
        struct RenamedToUnestimableName {
            let dish: SyncedDish
            let client: NuToriAPIClient
            let rice: SyncedIngredient

            init() async throws {
                let base = try EstimatedDish()
                dish = base.dish
                rice = base.rice
                client = base.client
                _ = try await client.pushSyncWrites(
                    [
                        .updateDish(
                            writeId: UUID(),
                            correction: DishCorrection(id: dish.id, name: "謎の料理", quantity: nil))
                    ], isFinalBatch: true, clientState: .fixture())
                // 偽のサーバーは、推定中を返した次の取得で推定し直す
                _ = try await client.pullSyncChanges(afterSequence: 2, clientState: .fixture())
            }

            @Test("次の取得で前の材料を消して料理なしを返すこと")
            func failsUnestimableName() async throws {
                let second = try await client.pullSyncChanges(
                    afterSequence: 4, clientState: .fixture())

                #expect(
                    second
                        == FakeSyncServerTests.page(
                            [
                                .ingredientDeletion(ingredientId: rice.id),
                                .dishEstimationStatus(.init(dishId: dish.id, status: .noDishes)),
                            ], next: 6))
            }
        }

        @Suite("量を直したとき")
        struct QuantityCorrected {
            let dish: SyncedDish
            let client: NuToriAPIClient
            let rice: SyncedIngredient

            init() async throws {
                let base = try EstimatedDish()
                dish = base.dish
                rice = base.rice
                client = base.client
                _ = try await client.pushSyncWrites(
                    [
                        .updateDish(
                            writeId: UUID(),
                            correction: DishCorrection(
                                id: dish.id, name: dish.name,
                                quantity: .init(
                                    value: 1.5,
                                    proportionedIngredients: [
                                        .init(ingredientId: rice.id, quantity: 300)
                                    ])))
                    ], isFinalBatch: true, clientState: .fixture())
            }

            @Test("直した量と比例させた材料の量を返し、推定し直さないこと")
            func correctsQuantity() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 2, clientState: .fixture())

                #expect(
                    result
                        == FakeSyncServerTests.page(
                            [
                                .dish(
                                    SyncedDish(
                                        id: dish.id, mealId: dish.mealId, name: dish.name,
                                        quantity: .init(value: 1.5, unit: "杯", source: .corrected),
                                        positionInMeal: 0, version: 2)),
                                .ingredient(
                                    FakeSyncServerTests.ingredient(
                                        rice.id, dishId: dish.id, name: "ご飯", quantity: 300)),
                            ], next: 4))
            }
        }

        @Suite("材料の量を直したとき")
        struct IngredientQuantityCorrected {
            let dish: SyncedDish
            let client: NuToriAPIClient
            let rice: SyncedIngredient

            init() async throws {
                let base = try EstimatedDish()
                dish = base.dish
                rice = base.rice
                client = base.client
                _ = try await client.pushSyncWrites(
                    [.updateIngredient(writeId: UUID(), ingredientId: rice.id, quantity: 150)],
                    isFinalBatch: true, clientState: .fixture())
            }

            @Test("直した量を返すこと")
            func correctsIngredientQuantity() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 2, clientState: .fixture())

                #expect(
                    result
                        == FakeSyncServerTests.page(
                            [
                                .ingredient(
                                    FakeSyncServerTests.ingredient(
                                        rice.id, dishId: dish.id, name: "ご飯", quantity: 150,
                                        source: .corrected))
                            ], next: 3))
            }
        }

        @Suite("料理を消したとき")
        struct Deleted {
            let dish: SyncedDish
            let client: NuToriAPIClient
            let rice: SyncedIngredient

            init() async throws {
                let base = try EstimatedDish()
                dish = base.dish
                rice = base.rice
                client = base.client
                _ = try await client.pushSyncWrites(
                    [.deleteDish(writeId: UUID(), dishId: dish.id)], isFinalBatch: true,
                    clientState: .fixture())
            }

            @Test("料理と材料の削除の印を返すこと")
            func deletesDishAndIngredients() async throws {
                let result = try await client.pullSyncChanges(
                    afterSequence: 2, clientState: .fixture())

                #expect(
                    result
                        == FakeSyncServerTests.page(
                            [
                                .dishDeletion(dishId: dish.id),
                                .ingredientDeletion(ingredientId: rice.id),
                            ], next: 4))
            }
        }
    }
}
