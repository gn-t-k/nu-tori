import Foundation
import NuToriAPI
import NuToriCore
import NuToriTestSupport
import Testing

extension SyncEngineTests {
    @Suite("まだ送れていない料理")
    struct UnsentDishes {
        let store: SyncBoxMock<RecordCacheMock>
        let transport: ClientTransportMock
        let engine: SyncEngine

        init() async throws {
            store = try await DishWrites.seededStore()
            transport = .sync()
            engine = .fixture(store: store, transport: transport)
        }

        @Test("足した料理は、送るまでまだ送れていない料理にすること")
        func addedDish() async throws {
            let dish = try #require(
                try await engine.addDish(named: "味噌汁", toMeal: DishWrites.mealId))

            #expect(try await engine.unsentDishIds() == [dish.id])
            _ = try await engine.sync()
            #expect(try await engine.unsentDishIds().isEmpty)
        }

        @Test("名前を直した料理は、送るまでまだ送れていない料理にすること")
        func renamedDish() async throws {
            try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")

            #expect(try await engine.unsentDishIds() == [DishWrites.dishId])
        }

        @Test("量だけを直した料理は、まだ送れていない料理にしないこと")
        func quantityCorrectedDish() async throws {
            try await engine.correctDishQuantity(id: DishWrites.dishId, to: 1.5)

            #expect(try await engine.unsentDishIds().isEmpty)
        }

        @Test("名前を直した書き込みも、料理を直す書き込みで送ること")
        func renameIsSentAsUpdate() async throws {
            try await engine.renameDish(id: DishWrites.dishId, to: "カツ丼")
            _ = try await engine.sync()

            let write = try #require(try transport.pushBodies.first?.writes.first)
            guard case .updateDish(_, let correction) = write else {
                Issue.record("料理を直す書き込みでない: \(write)")
                return
            }
            #expect(correction.name == "カツ丼")
        }
    }
}
